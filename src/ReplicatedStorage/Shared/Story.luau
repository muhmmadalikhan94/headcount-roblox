-- HEADCOUNT: every line of story text. Edit freely; the server reads scenes by name.
-- Scene lines are { speaker, text, seconds }. Speakers are defined in Story.Speakers.

local Story = {}

Story.Quote = "\"Stay with your group. Wait for headcount. Never, ever answer the whistle.\""
Story.QuoteSource = "Camp Hollow Pines rulebook, 1987"

Story.Speakers = {
	MARCY = { Label = "MARCY (radio)", Color = Color3.fromRGB(150, 225, 165), Radio = true },
	THOUGHT = { Label = "YOU", Color = Color3.fromRGB(225, 225, 225), Italic = true },
	TAPE = { Label = "TAPE", Color = Color3.fromRGB(215, 195, 150) },
	WRONG = { Label = "TAPE", Color = Color3.fromRGB(255, 60, 60) },
	PA = { Label = "PA SYSTEM", Color = Color3.fromRGB(255, 130, 95) },
	TWELFTH = { Label = "", Color = Color3.fromRGB(255, 35, 35) },
	CRANE = { Label = "VOICE", Color = Color3.fromRGB(200, 175, 255), Radio = true },
	SOUND = { Label = "", Color = Color3.fromRGB(175, 175, 175), Italic = true },
}

Story.Chapters = {
	[0] = "PROLOGUE: BREAKDOWN",
	[1] = "CHAPTER 1: THE GATE",
	[2] = "CHAPTER 2: THE CABINS",
	[3] = "CHAPTER 3: THE LAKE",
	[4] = "CHAPTER 4: THE MESS HALL",
	[5] = "CHAPTER 5: THE DIRECTOR'S OFFICE",
	[6] = "CHAPTER 6: THE FLAGPOLE",
}

Story.Pages = {
	[1] = {
		Title = "Day 1",
		Text = "The kids arrived today. Eleven of them, all sunburned and loud. I counted them twice at the flagpole. Director Crane laughed and said I take headcount too seriously. You can never be too careful out here.",
	},
	[2] = {
		Title = "Day 4",
		Text = "Headcount said twelve tonight. There are only eleven kids. I counted again: twelve. I checked every face. None of the kids see the extra one. But I do. It stands at the very back of the line.",
	},
	[3] = {
		Title = "Day 6",
		Text = "It copies me. When I blow my whistle, it blows one too, three times, always three. Last night I saw it standing by the trees with the roster in its hands. It was holding a pencil.",
	},
	[4] = {
		Title = "Day 9",
		Text = "Two kids are gone. The others say they went home early. They didn't. Their parents never came. I checked the roster: their names were crossed out. In MY handwriting. I never wrote that.",
	},
	[5] = {
		Title = "Day 10",
		Text = "I think it's trying to take my job. It wants to be the counselor. It's doing headcount now, and every time it counts someone, they stop being here. Fire keeps it back. I'm keeping the campfire burning all night.",
	},
	[6] = {
		Title = "Day 13",
		Text = "Three kids left. I tried to drive them out. The road just looped back to the gate, over and over, like the camp won't let go. It won't let us leave until the count is finished.",
	},
	[7] = {
		Title = "Day 14",
		Text = "I understand now. It doesn't want the kids. It wants the ROSTER to be right. It's tied to that list. As long as the roster exists, it can't die. Twelve names, twelve at the flagpole. If someone fills the last spot, maybe it stops.",
	},
	[8] = {
		Title = "Last entry",
		Text = "I'm going to sign my name on the last line. Maybe that finishes the count. If someone ever reads this: DON'T sign. Burn it. Fire is the only thing it fears. And if you hear three whistles... RUN.",
	},
	[9] = {
		Title = "From the desk of Director W. Crane",
		Text = "The camp has always needed a counselor. When this one is gone, it will need another. The roster always fills itself. I am sorry. I signed first.",
		Secret = true,
	},
}

Story.RosterNames = {
	"Danny Ortiz",
	"Becca Lyle",
	"Tommy Pruitt",
	"Jen Akers",
	"Lucas Bram",
	"Kimmy Shaw",
	"Owen Healy",
	"Rosa Delgado",
	"Pete Varga",
	"Annie Coyle",
	"Sam Whitlock",
}

Story.Scenes = {
	Prologue = {
		{ "THOUGHT", "No signal. No gas. Perfect.", 3.5 },
	},
	KitOpened = {
		{ "THOUGHT", "Emergency kit. Flares. Better than nothing.", 3.5 },
	},
	PrologueWhistle = {
		{ "SOUND", "*A whistle. Three short blasts.*", 3.5 },
	},
	GateArrive = {
		{ "THOUGHT", "The bars are bent apart. Something big squeezed through... from the inside.", 4.5 },
		{ "THOUGHT", "'Stay with your... counselor'? Someone carved that in.", 4 },
	},
	GateRadio = {
		{ "MARCY", "Hello? Is someone there? Oh thank God.", 3.5 },
		{ "MARCY", "Listen to me. You need to keep your voices down. It hears everything.", 4.5 },
		{ "MARCY", "My name is Marcy. I'm the counselor here.", 3.5 },
		{ "MARCY", "Don't go back to the road; it just loops back to this gate. I've tried. The only way out is through the camp.", 6 },
		{ "MARCY", "I kept a journal. The pages got scattered. If you find them, you'll understand what it is.", 5 },
		{ "MARCY", "And please... if you see something tall with red eyes, don't stare at it. Just move.", 5 },
	},
	RoadLoop = {
		{ "THOUGHT", "Wait... this is the gate again. The road led me right back here.", 4 },
	},
	RoadLoopRadio = {
		{ "MARCY", "I told you. The road just loops back to the gate.", 4 },
	},
	CabinsArrive = {
		{ "THOUGHT", "The campfire logs are still warm.", 3 },
		{ "THOUGHT", "It's too neat. Like the kids just stepped out.", 3.5 },
	},
	FirstSighting = {
		{ "MARCY", "You saw it, didn't you? That's the twelfth one.", 4 },
		{ "MARCY", "Don't let it get close. It was just watching back then too. At first.", 5 },
	},
	FlareBoxes = {
		{ "MARCY", "Those red boxes... the rescue team left them after we disappeared.", 4.5 },
		{ "MARCY", "Grab whatever you can. You're going to need it.", 3.5 },
	},
	CanoeKnock = {
		{ "SOUND", "*Knock. Knock. Knock.* (from under the canoe)", 3.5 },
	},
	CanoeFlip = {
		{ "THOUGHT", "Nothing. Just... wet footprints. Leading into the water.", 4 },
	},
	LakeWhistle = {
		{ "SOUND", "*Three whistles. Close this time.*", 2.5 },
	},
	LakeChase = {
		{ "MARCY", "RUN! Get to the boathouse!", 2.5 },
		{ "MARCY", "Use the flares. It hates fire. It hates it!", 3.5 },
		{ "MARCY", "Bar the door behind you!", 3 },
	},
	SafeInBoathouse = {
		{ "MARCY", "Okay... okay. You're okay.", 3 },
		{ "MARCY", "Fire. That's how I kept the kids safe for as long as I did.", 4 },
		{ "MARCY", "We had campfires every night. It wouldn't come near the light.", 4 },
	},
	LakeChaseOver = {
		{ "MARCY", "It went back into the water... Find my pages in the boathouse. Hurry.", 4.5 },
	},
	MessHall = {
		{ "THOUGHT", "The tables are set for twelve...", 3 },
		{ "THOUGHT", "One plate is clean. Licked clean.", 3.5 },
		{ "MARCY", "The generator's in the back room. It needs three fuses. The kids used to hide them to skip chores.", 6 },
	},
	PA = {
		{ "PA", "ATTENTION, CAMPERS.", 2.5 },
		{ "PA", "PLEASE REPORT TO THE FLAGPOLE FOR HEADCOUNT.", 3.5 },
		{ "PA", "ATTENDANCE IS... MANDATORY.", 3.5 },
		{ "MARCY", "That's not me. That's not me! It's learned my voice!", 4 },
	},
	KitchenWhistle = {
		{ "SOUND", "*Three whistles. From the kitchen.*", 2.5 },
	},
	BigChase = {
		{ "MARCY", "Flares! Hit it with everything you've got! Four hits!", 4 },
	},
	FirstKill = {
		{ "MARCY", "Did you... did you KILL it?", 4 },
	},
	ItsBack = {
		{ "SOUND", "*Three whistles, far away.*", 3 },
		{ "MARCY", "No. It's back. It always comes back.", 3.5 },
		{ "MARCY", "We need to find out why. Find the rest of my pages.", 4 },
	},
	ChaseOverNoKill = {
		{ "MARCY", "It's gone... for now. Find the rest of my pages. Please.", 4.5 },
	},
	Whistles = {
		{ "SOUND", "*Three whistles echo through the camp.*", 3 },
	},
	WhistlesFar = {
		{ "SOUND", "*Three whistles, far away.*", 3 },
	},
	GotKey = {
		{ "THOUGHT", "A rusty key. The tag says DIRECTOR.", 3.5 },
		{ "MARCY", "Crane's office is the cabin on the hill. He never let anyone in there.", 4.5 },
	},
	OfficeLetter = {
		{ "MARCY", "Crane knew. He KNEW. He brought it here...", 4.5 },
	},
	ToFlagpole = {
		{ "MARCY", "The flagpole. That's where it does headcount. That's where this ends.", 4.5 },
	},
	Roster = {
		{ "THOUGHT", "Eleven names crossed out in red. And the twelfth...", 4 },
		{ "MARCY", "That's where I signed. I thought it would end it.", 4 },
		{ "MARCY", "It didn't. It just... kept me here.", 4 },
	},
	FinaleWhistle = {
		{ "SOUND", "*Three whistles. From every direction at once.*", 3 },
	},
	Headcount = {
		{ "TWELFTH", "Headcount.", 3 },
	},
	Finale = {
		{ "MARCY", "Burn the roster! Hit the roster with a flare!", 3.5 },
		{ "MARCY", "Stun it first, it won't let the roster burn while it's watching!", 4.5 },
		{ "MARCY", "I'll keep its attention as long as I can!", 3.5 },
	},
	RosterResist = {
		{ "MARCY", "It won't catch while it's watching! Stun it first!", 3 },
	},
	RosterBurning = {
		{ "MARCY", "It's burning! Again! Hit it again!", 3 },
	},
	Victory = {
		{ "SOUND", "*The Twelfth screams. It burns from the inside out.*", 4 },
	},
	EndingA = {
		{ "MARCY", "It's quiet. It's actually quiet.", 3.5 },
		{ "MARCY", "Thank you. I think... I think I can go home now.", 4.5 },
		{ "SOUND", "*The radio fades to static. Back at the gate, the chains have fallen off.*", 5 },
	},
	EndingC = {
		{ "SOUND", "*The walkie crackles one last time. It's not Marcy.*", 4.5 },
		{ "CRANE", "Camp opens again next summer. We'll need a new counselor.", 4.5 },
		{ "CRANE", "Welcome aboard.", 3 },
	},
	EndingB = {
		{ "SOUND", "*The sound of a pencil scratching.*", 3.5 },
		{ "TWELFTH", "Headcount complete.", 4 },
	},
	Revived = {
		{ "MARCY", "Somehow you slipped off the list. Don't let it count you again.", 4 },
	},
}

-- %s is the name of the survivor who ends up holding Marcy's whistle (secret ending).
Story.WhistleLine = "*%s finds the whistle in their hand. They can't let go of it.*"

Story.Endings = {
	A = { Title = "HEADCOUNT: 0", Subtitle = "Camp Hollow Pines is closed." },
	B = { Title = "COUNTED", Subtitle = "See you next summer." },
	C = { Title = "HEADCOUNT: 1", Subtitle = "Applications are now closed." },
}

return Story
