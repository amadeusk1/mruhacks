extends Interactable
## Cashier spot in front of the chip window. Town coins buy play chips, and chips cash back out as coins.

func _ready() -> void:
	title = "Chip window"
	verb = "Cashier"
	reach = 1.6
	super._ready()
	add_to_group("cashier")


func interact(_player: Node) -> bool:
	if UIRouter.top() is Cashier:
		return true
	var ui := Cashier.new()
	ui.setup("Chip window", "One coin buys %d chips. Every %d chips cashes out as one coin." % [Casino.COIN_CHIPS, Casino.COIN_CHIPS], 560.0)
	ui.build()
	ui.open()
	ui._refresh()
	return true


class Cashier:
	extends UIModal
	var _chips: Label
	var _cashable: Label
	var _coins: Label
	var _note: Label
	var _buy1: Button
	var _buy5: Button
	var _cash10: Button
	var _cash_all: Button

	func build() -> void:
		_chips = UIKit.label("Play chips  0", "Strong", HORIZONTAL_ALIGNMENT_CENTER)
		_cashable = UIKit.label("Can cash  0", "Body", HORIZONTAL_ALIGNMENT_CENTER)
		_coins = UIKit.label("Coins  0", "Body", HORIZONTAL_ALIGNMENT_CENTER)
		body.add_child(_chips)
		body.add_child(_cashable)
		body.add_child(_coins)
		var buy := UIKit.hbox(10)
		buy.alignment = BoxContainer.ALIGNMENT_CENTER
		_buy1 = CasinoKit.action("1 coin", "primary", 220)
		_buy5 = CasinoKit.action("5 coins", "primary", 220)
		_buy1.pressed.connect(_buy.bind(1))
		_buy5.pressed.connect(_buy.bind(5))
		buy.add_child(_buy1)
		buy.add_child(_buy5)
		body.add_child(buy)
		var cash := UIKit.hbox(10)
		cash.alignment = BoxContainer.ALIGNMENT_CENTER
		_cash10 = CasinoKit.action("Cash 10", "secondary", 220)
		_cash_all = CasinoKit.action("Cash all", "secondary", 220)
		_cash10.pressed.connect(_cash.bind(Casino.COIN_CHIPS))
		_cash_all.pressed.connect(_cash_all_pressed)
		cash.add_child(_cash10)
		cash.add_child(_cash_all)
		body.add_child(cash)
		_note = UIKit.label("", "Muted", HORIZONTAL_ALIGNMENT_CENTER)
		_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(_note)
		if not Casino.purse.is_connected(_on_purse):
			Casino.purse.connect(_on_purse)
		if not Casino.notice.is_connected(_on_notice):
			Casino.notice.connect(_on_notice)
		if not Casino.paid.is_connected(_refresh):
			Casino.paid.connect(_refresh)
		Casino.sync()

	func _buy(coins: int) -> void:
		var world := _world()
		if world == null or not world.has_method("spend_coins") or not bool(world.call("spend_coins", coins)):
			_note.text = "Not enough coins."
			_refresh()
			return
		Casino.buy(coins)
		_refresh()

	func _cash(amount: int) -> void:
		Casino.cash_out(amount)
		_refresh()

	func _cash_all_pressed() -> void:
		_cash(Casino.cashable_shown)

	func _on_purse(_chips_n: int, _cashable_n: int) -> void:
		_refresh()

	func _on_notice(table: String, message: String) -> void:
		if table != "":
			return
		_note.text = message
		_refresh()

	func _refresh(_paid := 0) -> void:
		if not is_inside_tree():
			return
		var coins := 0
		var hud := get_tree().get_first_node_in_group("play_hud")
		if hud != null:
			coins = int(hud.get("coins"))
		_chips.text = "Play chips  %d" % Casino.chips_shown
		_cashable.text = "Cashes for  %d coins" % int(Casino.cashable_shown / float(Casino.COIN_CHIPS))
		_coins.text = "Coins  %d" % coins
		_buy1.disabled = coins < 1
		_buy5.disabled = coins < 5
		_cash10.disabled = Casino.cashable_shown < Casino.COIN_CHIPS
		_cash_all.disabled = Casino.cashable_shown < Casino.COIN_CHIPS

	func _world() -> Node:
		return get_tree().get_first_node_in_group("world")
