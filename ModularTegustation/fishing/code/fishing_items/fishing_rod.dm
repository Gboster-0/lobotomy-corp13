
/**
 *
 * Modular file containing: fishing rods
 * The bread and butter of fishing, without this everything else is basically worthless
 *
 */

#define ROD_SLOT_LINE "line"
#define ROD_SLOT_HOOK "hook"
#define FISHSKILLEXP(A) user.mind?.adjust_experience(/datum/skill/fishing, A)

/obj/item/fishing_rod
	name = "ramshackle fishing rod"
	desc = "A tool used to dredge up aquatic entities. Though since the pole is so weak you may as well be handline fishing, a technique where you hold the line with your hands."
	icon = 'ModularTegustation/fishing/icons/fishing.dmi'
	icon_state = "rod"
	lefthand_file = 'icons/mob/inhands/64x64_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/64x64_righthand.dmi'
	inhand_icon_state = "rod"
	inhand_x_dimension = 64
	inhand_y_dimension = 64
	slot_flags = ITEM_SLOT_BELT
	w_class = WEIGHT_CLASS_HUGE
	/* Inherent power of the rod. This may vary
		due to quality meaning you will need to
		counter a negative level with hooks, lines,
		or skill. */
	var/rod_level = 0.6
	//Fishing Equipment
	var/obj/item/fishing_component/line/line
	var/obj/item/fishing_component/hook/hook
	//Overlay Line Color
	var/default_line_color = "gray"
	//If already fishing
	var/isfishing = FALSE
	//Fishing Visuals
	var/list/current_fishing_visuals = list()
	//what base mod do you have?
	var/speed_modifier = 1
	//what bonus do you get from the moon? Normal rods get 0
	var/lunar_modifier = 0

	//do we override the default fishing speed? (should be used if you want to debug something or make a rod with unique speed)
	var/speed_override = FALSE

/obj/item/fishing_rod/examine(mob/living/user)
	. = ..()
	. += span_notice("This rod has a modifier of +[ReturnRodPower(user)].")
	. += span_notice("This rod has a speed modifier of +[speed_modifier].")

/obj/item/fishing_rod/attackby(obj/item/attacking_item, mob/user, params)
	if(SlotCheck(attacking_item,ROD_SLOT_LINE))
		UseSlot(ROD_SLOT_LINE, user, attacking_item)
		return TRUE
	else if(SlotCheck(attacking_item,ROD_SLOT_HOOK))
		UseSlot(ROD_SLOT_HOOK, user, attacking_item)
		return TRUE
	return ..()

/obj/item/fishing_rod/afterattack(atom/target, mob/user, proximity_flag)
	if(istype(target, /turf/open/water/deep) && isliving(user) && !isfishing && user.z == target.z)
		if(istype(user.get_inactive_held_item(), /obj/item/fishing_rod))
			to_chat(user, span_notice("You attempt to cast two lines at once but they get tangled together."))
			return
		//Multicasting is too chaotic
		if(isfishing == TRUE)
			return
		if(!BobberThrow(user, target))
			return
		StartFishing(user, target) //Maybe we can make it call something else with this proc.
		return
	return ..()

/obj/item/fishing_rod/proc/StartFishing(mob/living/user, turf/open/water/deep/fishing_spot)
	isfishing = TRUE
	user.visible_message(span_notice("[user] begins fishing in [fishing_spot]."), span_notice("You begin fishing."))
	playsound(get_turf(fishing_spot), 'sound/abnormalities/piscinemermaid/bigsplash.ogg', 20, 0, 3)
	//Fishing visuals, first make a bobber.
	FishShapes("bobber", fishing_spot)
	var/list/fishing_turf = RegisterFishingArea(fishing_spot)
	//Redundant check for safety concerns.
	if(!fishing_turf.len)
		return StopFishing()
	//MAKE VISUALS
	StirWaterVisuals(fishing_turf, fishing_spot)

	//copy turf loottables
	var/things_to_fish = ReturnLootTable(user, fishing_spot)

		//~~~FISHING BEGINS~~~
	for(var/i = 1 to 100)
		if(!FishCycle(user, fishing_spot, things_to_fish))
			break
		//Randomizes the rarity of the list every time its complete. Might be a blight on processing and needs improvement or rework. -IP
		things_to_fish = ReturnLootTable(user, fishing_spot)

	return StopFishing()

/* FishCycle is one cycle of fishing. You catch a fish
	when this is over and then cycle to this proc again.
	If this proc returns FALSE you will stop cycling.*/
/obj/item/fishing_rod/proc/FishCycle(mob/living/user, turf/open/water/deep/fishing_spot, list/loottable)
	//If no one is there to pull the reel who really is fishin now mmmm?
	if(!user.client)
		return FALSE

	//Time required for fishing
	var/fishing_time
	//default fishing skill
	var/fishing_skill = 0
	//Do we have the skill? Do we even have a mind?
	if(user.mind)
		fishing_skill = user.mind.get_skill_level(/datum/skill/fishing)
	//random extra time to the fishing for a unpredictable feel rather than making a chance to just not fish up anything.
	if(!speed_override)
		fishing_time = (8 + rand(0,2) - fishing_skill) SECONDS
	else
		fishing_time = speed_override

	if(!do_after(user, fishing_time/speed_modifier, target = fishing_spot))
		isfishing = FALSE
		return FALSE
	//Redundant repeat of Fish skill check in order to apply EXP
	if(user.mind)
		FISHSKILLEXP(5)
	if(loottable.len)
		//Fishing successful, gain 0.1 devotion
		user.devotion+=0.1
		if(user.devotion>= 5 && (SSmaptype.maptype in SSmaptype.citymaps))
			to_chat(user, span_notice("You fish, pray and gain some devotion."))
		FishLoot(pickweight(loottable), user, get_turf(fishing_spot))
	else
		to_chat(user, span_notice("The water remains still. You dont catch anything."))
	return TRUE

//Proc for returning loot table chances.
/obj/item/fishing_rod/proc/ReturnLootTable(mob/living/wielder, turf/open/water/deep/water_turf)
	var/fishing_power = ReturnRodPower(wielder)
	fishing_power *= (SSfishing.moonphase-0.5)*0.5
	return water_turf.ReturnChanceList(fishing_power)

/*Tgstation uses signals and projectiles for their fishing rods
	but im not too familiar with signals so for now
	Bobber throw for checking if there is anything blocking the turf we fish. */
/obj/item/fishing_rod/proc/BobberThrow(mob/living/user, bobber_target)
	var/turf/target_turf = get_turf(bobber_target)
	var/fish_distance = get_dist_euclidian(get_turf(target_turf), get_turf(src))
	if(fish_distance >= 7)
		to_chat(user, span_notice("The bobber is [round(fish_distance - 7) + 1] tiles short of its destination."))
		return FALSE
	/*Cycles 7 times until it returns. Wallcheck checks the turf after
		this turf and if that turf equals the target turf we return TRUE.
		If the Wallcheck returns a false proc on ClearSky then we return FALSE.
		Clearsky checks if the turf has a window in it or a solid wall. */
	var/turf/this_turf = get_turf(src)
	var/turf/wallcheck
	for(var/i=0 to 7)
		if(this_turf == target_turf)
			return TRUE
		wallcheck = get_step(this_turf, get_dir(this_turf, target_turf))
		if(!ClearSky(wallcheck))
			to_chat(user, span_notice("The bobber donks off of an obstacle."))
			return FALSE
		this_turf = wallcheck

/*For checking turf to where the bobber lands. Same check as
	/mob/living/simple_animal/hostile/ordeal/steel_dawn/steel_noon/flying. -IP */
/obj/item/fishing_rod/proc/ClearSky(turf/T)
	if(!T || isclosedturf(T) || T == loc)
		return FALSE
	if(locate(/obj/structure/window) in T.contents)
		return FALSE
	for(var/obj/machinery/door/D in T.contents)
		if(D.density)
			return FALSE
	return TRUE

//Unique Fish Retrieval
/obj/item/fishing_rod/proc/FishLoot(obj/item/fished_thing, mob/living/carbon/human/user, turf/fish_land)
	var/obj/item/potential_fishie = new fished_thing(get_turf(user))
	if(istype(potential_fishie, /obj/item/food/fish))
		var/obj/item/food/fish/fishie = potential_fishie
		var/size_modifier = rand(1, 4) * 0.1
		//Size modifier has to be a decimal in order to keep it from making massive fish.
		//Gets bonuses if mercury is in alignment, and if you're aligned with the mercury god
		if(SSfishing.IsAligned(/datum/planet/mercury))
			size_modifier *= 1.3
			to_chat(user, span_nicegreen("[FISHGOD_MERCURY] smiles upon you!."))

		if(user.god_aligned == FISHGOD_MERCURY)
			size_modifier *= 2

		fishie.randomize_weight_and_size(size_modifier)

		if(user.god_aligned == FISHGOD_URANUS && prob(5))
			to_chat(user, span_nicegreen("Abena Mansa smiles upon you! You caught some cash!"))
			new /obj/item/stack/spacecash/c50(get_turf(user))

		if(CheckPlanetAligned(FISHGOD_SATURN))
			var/list/possible_messages = list("Your mind feels clearer after fishing.", "You feel relaxed in [FISHGOD_SATURN]'s light.")
			to_chat(user, span_nicegreen("Saturn is in alignment. [pick(possible_messages)]"))
			user.adjustSanityLoss(-5)

		to_chat(user, span_nicegreen("You caught [fishie.name]."))
		if(user.mind)
			FISHSKILLEXP(10)
	playsound(fish_land, 'sound/effects/fish_splash.ogg', 18, 0, 3)

	//Icon Stuff
/obj/item/fishing_rod/update_overlays()
	. = ..()
	var/line_color = line?.line_color || default_line_color
	/// Line part by the rod, always visible
	var/mutable_appearance/reel_overlay = mutable_appearance(icon, "reel_overlay")
	reel_overlay.color = line_color;
	. += reel_overlay

	// Line & hook is also visible when only bait is equipped but it uses default appearances then
	if(hook)
		var/mutable_appearance/line_overlay = mutable_appearance(icon, "line_overlay")
		line_overlay.color = line_color;
		. += line_overlay
		var/mutable_appearance/hook_overlay = mutable_appearance(icon, hook?.rod_overlay_icon_state || "hook_overlay")
		. += hook_overlay

/obj/item/fishing_rod/worn_overlays(mutable_appearance/standing, isinhands, icon_file)
	. = ..()
	var/line_color = line?.line_color || default_line_color
	var/mutable_appearance/reel_overlay = mutable_appearance(icon_file, "reel_overlay")
	reel_overlay.appearance_flags |= RESET_COLOR
	reel_overlay.color = line_color
	. += reel_overlay
	/// if we don't have anything hooked show the dangling hook & line
	if(isinhands)
		var/mutable_appearance/line_overlay = mutable_appearance(icon_file, "line_overlay")
		line_overlay.appearance_flags |= RESET_COLOR
		line_overlay.color = line_color
		. += line_overlay
		. += mutable_appearance(icon_file, "hook_overlay")

	//Stop Fishing
/obj/item/fishing_rod/proc/StopFishing()
	if(current_fishing_visuals.len)
		for(var/turf/T in current_fishing_visuals)
			if(!T)
				continue
			T.cut_overlay(current_fishing_visuals[T])
	isfishing = FALSE

	//Registers tiles around bobber.
/obj/item/fishing_rod/proc/RegisterFishingArea(turf/open/fishing_tile)
	if(!isturf(fishing_tile))
		return
	var/list/water_tiles = list()
	for(var/turf/T in range(2, fishing_tile))
		if(!istype(T, fishing_tile.type))
			continue
		LAZYADD(water_tiles, T)
	if(water_tiles.len)
		return water_tiles

//Core proc for visual effects
/obj/item/fishing_rod/proc/StirWaterVisuals(list/water_body, turf/open/fishing_tile)
	var/list/no_overlap_fish_turf = water_body.Copy()
	//do not spawn a fish visual ontop of the bobber
	no_overlap_fish_turf -= fishing_tile

	var/list/visuals_list = list("fish_dancing", "fish_pacing", "fish_pacing2", "fish_mass")
		//Polluted water should not have fish that can be seen easily.
	if(istype(fishing_tile, /turf/open/water/deep/polluted))
		visuals_list = list("fish_mass")
	for(var/visable_feesh = 0 to 3)
		if(!no_overlap_fish_turf.len || !visuals_list.len)
			break
		FishShapes(pick(visuals_list), pick_n_take(no_overlap_fish_turf), TRUE)

/* Applys overlays of fish shadows to water tiles.
	Do not fear for we have a list of the overlays
	we apply so we can remove them at will.*/
/obj/item/fishing_rod/proc/FishShapes(icon_shape, turf/presence_in_water, underwater_shadow = FALSE)
	if(!isturf(presence_in_water))
		return
	var/mutable_appearance/under_the_waves = mutable_appearance(icon, icon_shape)
	//IS IT A SHAPE OR IS IT A BOBBER?
	if(underwater_shadow)
		under_the_waves.color = "BLACK"
		under_the_waves.alpha = 100
	//ADD THE OVERLAY TO THE LIST
	current_fishing_visuals += presence_in_water
	current_fishing_visuals[presence_in_water] = under_the_waves
	presence_in_water.add_overlay(under_the_waves)

//Rod Customization
/obj/item/fishing_rod/proc/UseSlot(slot, mob/user, obj/item/new_item)
	var/obj/item/current_item
	switch(slot)
		if(ROD_SLOT_HOOK)
			current_item = hook
		if(ROD_SLOT_LINE)
			current_item = line
	if(!new_item && !current_item)
		return
	// Trying to remove the item
	if(!new_item && current_item)
		user.put_in_hands(current_item)
		update_icon()
		return
	// Trying to insert item into empty slot
	if(new_item && !current_item)
		if(!SlotCheck(new_item, slot))
			return
		if(user.transferItemToLoc(new_item,src))
			switch(slot)
				if(ROD_SLOT_HOOK)
					hook = new_item
				if(ROD_SLOT_LINE)
					line = new_item
			update_icon()
	/// Trying to swap item
	if(new_item && current_item)
		if(!SlotCheck(new_item,slot))
			return
		if(user.transferItemToLoc(new_item,src))
			switch(slot)
				if(ROD_SLOT_HOOK)
					hook = new_item
				if(ROD_SLOT_LINE)
					line = new_item
		user.put_in_hands(current_item)
		update_icon()

/// Checks if the item fits the slot
/obj/item/fishing_rod/proc/SlotCheck(obj/item/item,slot)
	if(!istype(item))
		return FALSE
	switch(slot)
		if(ROD_SLOT_HOOK)
			if(!istype(item,/obj/item/fishing_component/hook))
				return FALSE
		if(ROD_SLOT_LINE)
			if(!istype(item,/obj/item/fishing_component/line))
				return FALSE
	return TRUE

	//Calculates fishing power
/obj/item/fishing_rod/proc/ReturnRodPower(mob/living/user)
	. = rod_level
	if(hook)
		if(istype(hook,/obj/item/fishing_component/hook))
			. += hook.fishing_value
	if(line)
		if(istype(line,/obj/item/fishing_component/line))
			. += line.fishing_value

	if(isliving(user))
		if(user.god_aligned == FISHGOD_NEPTUNE)
			. *=1.4

	//Only a few rods will use this
	if(lunar_modifier!=0)
		. *=lunar_modifier*SSfishing.moonphase



//Upgraded Varients
//All of these have benefits and drawbacks
/obj/item/fishing_rod/fiberglass
	name = "fibreglass fishing rod"
	desc = "A tool used to dredge up aquatic entities. This rod is pretty reliable all things considered."
	icon_state = "rod_fibreglass"
	rod_level = 1		//Generally all round better.
	speed_modifier = 1.2

/obj/item/fishing_rod/gold
	name = "golden fishing rod"
	desc = "A tool used to dredge up aquatic entities. A beautiful, gold-encrusted rod. Expensive. Catches fish faster."
	icon_state = "rod_gold"
	speed_modifier = 1.5 //Just like minecraft.

/obj/item/fishing_rod/titanium
	name = "titanium fishing rod"
	desc = "A tool used to dredge up aquatic entities. An excellently built titanium rod. Catches better fish."
	icon_state = "rod_titanium"
	rod_level = 1.4

/obj/item/fishing_rod/lunar
	name = "lunar fishing rod"
	desc = "A tool used to dredge up aquatic entities. A pink rod. Heaven knows how it got this color. It's unremarkable, but does get it's power from the full moon."
	icon_state = "rod_gold"
	lunar_modifier = 1

//Gacha Rods. Obtained through gacha crates.
/obj/item/fishing_rod/wellcheers
	name = "Wellcheers fishing rod"
	desc = "One of S-Corp's famous fishing rods. They're known to be the best fishing rods in the city."
	icon_state = "rod_wellcheer"
	speed_modifier = 2
	rod_level = 2


#undef ROD_SLOT_LINE
#undef ROD_SLOT_HOOK
#undef FISHSKILLEXP
