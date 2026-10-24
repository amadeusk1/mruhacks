# Table pitch: MRUHacks 2026, prompt "Revitalize"



## Full walkthrough (~2 min)

**Opener: the problem (~20 s)**

> Hi, we're [team name], and this is Pengloo.
>
> A lot of us grew up on Club Penguin. It was where we hung out after school: you logged in, found your friends, and just stayed.
>
> You decorated your igloo, adopted a puffle, begged your parents for a membership, and raced your friends down Sled Hill. For a lot of us it was the first place online that felt like ours. [Optional: one real memory from someone on the team, in one sentence.]
>
> Then in 2017, Disney shut it down, and the fan servers that kept it going got taken down too.
>
> Now our friends are spread across group chats and Discord servers. Those work for messaging, but there's nowhere to *be* together. The prompt is "Revitalize," so we're bringing that place back as a cozy online world you share with friends, with original characters and new things to do together.

**Pengloo (key art, ~13 s)**

> This is Pengloo, a cozy island where you hang out with your friends as penguins. Club Penguin worked because your friends were right there with you, and that's what we built Pengloo around.

**Walk anywhere (~7 s)**

> Click anywhere and your penguin walks there. Take the bus to go anywhere on the island.

**Multiplayer (~7 s)**

> It's multiplayer: your friends walk around with you in real time, and with proximity voice chat you hear them when you're close.

**Minigames (~5 s)**

> And there are things to do together: basketball, sled races, and movie night in the cinema.

**What we learned (~6 s)**

> This was our first time building a 3D game with Godot and Blender, so pathfinding, cameras and 3D models were all new to us.

**Let's play (~2 s)**

> Let me show you.

**Close (~10 s)**


## Short version (~30 s)

> We're [team name]. Club Penguin was where a lot of us hung out with friends, and it's gone. For "Revitalize" we're bringing it back as Pengloo, a cozy online world with original characters.
>
> *(Click to walk, take the bus.)* You walk around, take the bus anywhere on the island, *(start the sled run)* and play activities like this sled run. It's built in Godot, with multiplayer, proximity voice chat, basketball and a shared cinema.

For a judge who comes back: "Since you were here, we [new thing]. Here it is." Then show only that.

## Q&A prep

Answer in one or two sentences, then offer to show it in the game.

**"Isn't this just Club Penguin? What about copyright?"**
> We took the idea and the feel of it. All the art is ours, and the plan is original bird characters with their own style. The concept art is in our repo.

**"Is it multiplayer?"**
> Yes. Everyone on the server shares the same town, and proximity voice chat lets you hear the penguins near you. *(Show two clients side by side.)*

**"Why Godot?"**
> It's free and open source, it's fast for building 3D scenes, and pathfinding and physics come built in. That saved us hours we didn't have in a 36-hour hackathon.

**"What was the hardest part?"**
Pick the one your team spent the most time on. These all come from the code:
- Click-to-walk pathfinding. The walkable area has to finish building before the penguin is placed, so we wait one physics step after a room loads.
- The igloo door. At first, walking out put you back inside the door trigger, which sent you straight back in. Now the landing spot sits outside the trigger.
- Switching into the sled minigame. The walking penguin and its camera are hidden and paused, and the sled scene brings its own camera and controls.

**"How does 'Revitalize' fit?"**
> We're bringing back something a lot of people lost when Club Penguin closed: an online place where you hang out with friends, which a chat app doesn't give you. It's that same idea, rebuilt as a new game.

**"What did you learn?"**
> It was our first time building a 3D game with Godot and Blender, so pathfinding, cameras and 3D models were all new to us.

**"What would you do with more time?"**
> More places and minigames, and more ways to dress up your penguin.

## Submission checklist

Drafts aren't judged, so the last step has to be Publish.

- [ ] Project title
- [ ] Description: inspiration (Club Penguin and its 2017 shutdown), purpose (a place for friends), what it does
- [ ] Cover image: a screenshot of the plaza or the sled run, or a concept image
- [ ] GitHub link: https://github.com/amadeusk1/mruhacks (already public)
- [ ] Optional: a short screen recording of the demo, as a backup in case the laptop dies
- [ ] Publish before the deadline
- [ ] After submissions close, note your table number (for example, B3)
