package main

import (
	"bufio"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

// Minimal RFC 6455 server side (handshake, masked client frames, fragmentation, ping/pong/close),
// so the lobby stays stdlib-only like the cinema gateway.
// shortcut: no permessage-deflate; Godot's frames are small binary packets, add it if relay bandwidth matters.

const (
	opCont   = 0
	opText   = 1
	opBinary = 2
	opClose  = 8
	opPing   = 9
	opPong   = 10
	wsGUID   = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
)

type wsConn struct {
	c      net.Conn
	br     *bufio.Reader
	wmu    sync.Mutex
	maxMsg int
	closed bool
}

func headerHas(h http.Header, name, token string) bool {
	for _, v := range h.Values(name) {
		for _, part := range strings.Split(v, ",") {
			if strings.EqualFold(strings.TrimSpace(part), token) {
				return true
			}
		}
	}
	return false
}

func isUpgrade(r *http.Request) bool {
	return strings.EqualFold(r.Header.Get("Upgrade"), "websocket") && headerHas(r.Header, "Connection", "upgrade") &&
		r.Header.Get("Sec-WebSocket-Version") == "13" && r.Header.Get("Sec-WebSocket-Key") != ""
}

func wsUpgrade(w http.ResponseWriter, r *http.Request, maxMsg int) (*wsConn, error) {
	if !isUpgrade(r) {
		return nil, errors.New("not a websocket request")
	}
	hj, ok := w.(http.Hijacker)
	if !ok {
		return nil, errors.New("hijack unsupported")
	}
	conn, brw, err := hj.Hijack()
	if err != nil {
		return nil, err
	}
	sum := sha1.Sum([]byte(r.Header.Get("Sec-WebSocket-Key") + wsGUID))
	resp := "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " +
		base64.StdEncoding.EncodeToString(sum[:]) + "\r\n"
	if p := r.Header.Get("Sec-WebSocket-Protocol"); p != "" { // browsers fail the socket if a requested protocol isn't echoed
		resp += "Sec-WebSocket-Protocol: " + strings.TrimSpace(strings.Split(p, ",")[0]) + "\r\n"
	}
	if _, err := brw.WriteString(resp + "\r\n"); err != nil {
		conn.Close()
		return nil, err
	}
	if err := brw.Flush(); err != nil {
		conn.Close()
		return nil, err
	}
	return &wsConn{c: conn, br: brw.Reader, maxMsg: maxMsg}, nil
}

// ReadMessage returns the next text/binary message, answering pings and closes itself.
// idle is the read deadline per frame (0 = none).
func (ws *wsConn) ReadMessage(idle time.Duration) (byte, []byte, error) {
	var msg []byte
	var msgOp byte
	for {
		if idle > 0 {
			ws.c.SetReadDeadline(time.Now().Add(idle))
		}
		var h [2]byte
		if _, err := io.ReadFull(ws.br, h[:]); err != nil {
			return 0, nil, err
		}
		fin, op, masked := h[0]&0x80 != 0, h[0]&0x0f, h[1]&0x80 != 0
		n := uint64(h[1] & 0x7f)
		switch n {
		case 126:
			var b [2]byte
			if _, err := io.ReadFull(ws.br, b[:]); err != nil {
				return 0, nil, err
			}
			n = uint64(binary.BigEndian.Uint16(b[:]))
		case 127:
			var b [8]byte
			if _, err := io.ReadFull(ws.br, b[:]); err != nil {
				return 0, nil, err
			}
			n = binary.BigEndian.Uint64(b[:])
		}
		if !masked {
			return 0, nil, errors.New("client frames must be masked")
		}
		if n > uint64(ws.maxMsg) || uint64(len(msg))+n > uint64(ws.maxMsg) {
			return 0, nil, errors.New("message too large")
		}
		var key [4]byte
		if _, err := io.ReadFull(ws.br, key[:]); err != nil {
			return 0, nil, err
		}
		payload := make([]byte, n)
		if _, err := io.ReadFull(ws.br, payload); err != nil {
			return 0, nil, err
		}
		for i := range payload {
			payload[i] ^= key[i%4]
		}
		switch op {
		case opPing:
			if err := ws.write(opPong, payload); err != nil {
				return 0, nil, err
			}
			continue
		case opPong:
			continue
		case opClose:
			ws.write(opClose, nil)
			return 0, nil, io.EOF
		case opText, opBinary:
			if msg != nil {
				return 0, nil, errors.New("new message inside a fragmented one")
			}
			msgOp, msg = op, payload
		case opCont:
			if msg == nil {
				return 0, nil, errors.New("continuation without a message")
			}
			msg = append(msg, payload...)
		default:
			return 0, nil, errors.New("unknown opcode")
		}
		if fin {
			return msgOp, msg, nil
		}
	}
}

func (ws *wsConn) WriteMessage(op byte, data []byte) error { return ws.write(op, data) }

func (ws *wsConn) write(op byte, data []byte) error {
	ws.wmu.Lock()
	defer ws.wmu.Unlock()
	if ws.closed {
		return net.ErrClosed
	}
	hdr := make([]byte, 2, 10)
	hdr[0] = 0x80 | op
	switch n := len(data); {
	case n < 126:
		hdr[1] = byte(n)
	case n <= 0xffff:
		hdr[1] = 126
		hdr = binary.BigEndian.AppendUint16(hdr, uint16(n))
	default:
		hdr[1] = 127
		hdr = binary.BigEndian.AppendUint64(hdr, uint64(n))
	}
	ws.c.SetWriteDeadline(time.Now().Add(10 * time.Second)) // a stalled peer can't block the relay forever
	if _, err := ws.c.Write(append(hdr, data...)); err != nil {
		return err
	}
	if op == opClose {
		ws.closed = true
	}
	return nil
}

func (ws *wsConn) Close() {
	ws.write(opClose, nil)
	ws.c.Close()
}
