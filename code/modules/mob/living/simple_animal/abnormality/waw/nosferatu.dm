#define NOSFERATU_BANQUET_COOLDOWN (12 SECONDS)
//Coded by Coxswain, sprited by crabby
/mob/living/simple_animal/hostile/abnormality/nosferatu
	name = "Nosferatu"
	desc = "A vampire, huh. Think I heard of it somewhere."
	icon = 'ModularTegustation/Teguicons/64x64.dmi'
	icon_state = "nosferatu"
	icon_living = "nosferatu"
	var/icon_aggro = "nosferatu_breach"
	portrait = "nosferatu"
	pixel_x = -16
	base_pixel_x = -16
	maxHealth = 2000
	health = 2000
	move_to_delay = 4
	rapid_melee = 1
	threat_level = WAW_LEVEL
	work_chances = list(
		ABNORMALITY_WORK_INSTINCT = list(40, 40, 45, 50, 50),
		ABNORMALITY_WORK_INSIGHT = list(30, 35, 35, 40, 45),
		ABNORMALITY_WORK_ATTACHMENT = list(30, 35, 35, 40, 45),
		ABNORMALITY_WORK_REPRESSION = list(0, 0, 45, 50, 50),
	)
	damage_coeff = list(RED_DAMAGE = 0.8, WHITE_DAMAGE = 1.2, BLACK_DAMAGE = 0.4, PALE_DAMAGE = 1.5)
	melee_damage_lower = 35
	melee_damage_upper = 45 //has a wide range, he can critically hit you
	melee_damage_type = RED_DAMAGE
	stat_attack = HARD_CRIT
	work_damage_amount = 8
	work_damage_type = RED_DAMAGE
	chem_type = /datum/reagent/abnormality/sin/envy
	attack_verb_continuous = "claws"
	attack_verb_simple = "claw"
	attack_sound = 'sound/abnormalities/nosferatu/attack.ogg'
	can_breach = TRUE
	start_qliphoth = 3
	ranged = TRUE

	ego_list = list(
		/datum/ego_datum/weapon/dipsia,
		/datum/ego_datum/weapon/banquet,
		/datum/ego_datum/armor/dipsia,
	)
	gift_type = /datum/ego_gifts/dipsia
	abnormality_origin = ABNORMALITY_ORIGIN_ARTBOOK

	observation_prompt = "I was human once, am still human. <br>I think. It's hard to tell anymore. <br>\
		He seemed lost, wandering the backstreets in such finery made him a tempting target, I never realised it was everyone else who was in danger. <br>\
		He wears the mask of humanity well, but a single drop of blood is all it took for him to reveal his ferocity. <br>\
		\"It's too early for a nap... <br>Won't you join me and share the pleasure?\" <br>He asks, his lips still red with my blood."
	observation_choices = list(
		"Join the Danse Macabre" = list(TRUE, "Refusing wasn't an option and he smiles, raising his glass. <br>\
			\"A toast then! To a night when one is allowed to pursue all kinds of desire, a never-ending blood-red night!\" <br>\
			Blood.... <br>The blood brings me eternal happiness, forfeiting false hope, let's forget all pretenses of humanity..."),
	)

	//work stuff
	var/feeding
	//breach stuff
	var/bloodlust = 4
	var/bloodlust_cooldown = 4
	var/blood = 0 //stored healing
	var/banquet_cooldown
	var/banquet_cooldown_time = 12 SECONDS
	var/banquet_damage = 100
	var/can_act = TRUE
	var/berzerk = FALSE
	//minion stuff
	var/list/spawned_bats = list()
	var/summon_cooldown_time = 60 SECONDS
	var/bat_spawn_limit = 6
	var/bat_spawn_number = 3

	//PLAYABLES ATTACKS
	attack_action_types = list(
		/datum/action/cooldown/nosferatu_banquet,
		/datum/action/innate/change_icon_nosf,
	)

//Playables buttons
/datum/action/cooldown/nosferatu_banquet
	name = "Banquet"
	icon_icon = 'icons/mob/actions/actions_abnormality.dmi'
	button_icon_state = "nosferatu"
	check_flags = AB_CHECK_CONSCIOUS
	transparent_when_unavailable = TRUE
	cooldown_time = NOSFERATU_BANQUET_COOLDOWN //12 seconds

/datum/action/innate/change_icon_nosf
	name = "Toggle Icon"
	desc = "Toggle your icon between breached and contained. (Works only for Limbus Company Labratories)"

/datum/action/innate/change_icon_nosf/Activate()
	. = ..()
	if(SSmaptype.maptype == "limbus_labs")
		owner.icon = 'ModularTegustation/Teguicons/64x64.dmi'
		owner.icon_state = "nosferatu"
		active = 1

/datum/action/innate/change_icon_nosf/Deactivate()
	. = ..()
	if(SSmaptype.maptype == "limbus_labs")
		owner.icon = 'ModularTegustation/Teguicons/64x64.dmi'
		owner.icon_state = "nosferatu_breach"
		active = 0

/datum/action/cooldown/nosferatu_banquet/Trigger()
	if(!..())
		return FALSE
	if(!istype(owner, /mob/living/simple_animal/hostile/abnormality/nosferatu))
		return FALSE
	var/mob/living/simple_animal/hostile/abnormality/nosferatu/nosferatu = owner
	if(nosferatu.IsContained()) // No more using cooldowns while contained
		return FALSE
	StartCooldown()
	nosferatu.Banquet()
	return TRUE

//work code
/mob/living/simple_animal/hostile/abnormality/nosferatu/FailureEffect(mob/living/carbon/human/user, work_type, pe)
	. = ..()
	datum_reference.qliphoth_change(-1)
	return

/mob/living/simple_animal/hostile/abnormality/nosferatu/AttemptWork(mob/living/carbon/human/user, work_type)
	if(work_type == ABNORMALITY_WORK_INSTINCT)
		feeding = TRUE
	else
		feeding = FALSE
	return ..()

/mob/living/simple_animal/hostile/abnormality/nosferatu/Worktick(mob/living/carbon/human/user) //take damage every work on instinct
	if(feeding)
		user.deal_damage(3, BLACK_DAMAGE)
		new /obj/effect/temp_visual/dir_setting/bloodsplatter(get_turf(user)) //Indicates damage being dealt to the player

/mob/living/simple_animal/hostile/abnormality/nosferatu/PostWorkEffect(mob/living/carbon/human/user, work_type, pe, work_time)
	switch(work_type)
		if(ABNORMALITY_WORK_INSTINCT)
			if(datum_reference.qliphoth_meter == 3)
				datum_reference.qliphoth_change(-3)
			else
				datum_reference.qliphoth_change(1)
		if(ABNORMALITY_WORK_REPRESSION)
			datum_reference.qliphoth_change(-1)
	return

//breach
/mob/living/simple_animal/hostile/abnormality/nosferatu/BreachEffect(mob/living/carbon/human/user, breach_type)
	. = ..()
	update_icon()
	playsound(get_turf(src), 'sound/abnormalities/nosferatu/transform.ogg', 50, 8) //big loud warning
	addtimer(CALLBACK(src, PROC_REF(BatSpawn)), 5 SECONDS)
	var/list/units_to_add = list(
		/mob/living/simple_animal/hostile/nosferatu_mob = 8
		)
	AddComponent(/datum/component/ai_leadership, units_to_add, 2, TRUE)

/mob/living/simple_animal/hostile/abnormality/nosferatu/update_icon_state()
	if(status_flags & GODMODE) // Not breaching
		icon_state = initial(icon_state)
	else // Breaching
		icon_state = icon_aggro
	icon_living = icon_state

/mob/living/simple_animal/hostile/abnormality/nosferatu/Move()
	if(!can_act)
		return FALSE
	var/turf/T = get_turf(src)
	if(!T)
		..()
		return
	for(var/obj/effect/decal/cleanable/blood/B in view(T, 2)) //will clean up any blood, but only heals from human blood
		if(B.blood_state == BLOOD_STATE_HUMAN)
			playsound(T, 'sound/abnormalities/nosferatu/bloodcollect.ogg', 25, 3)
			if(B.bloodiness == 100) //Bonus for "pristine" bloodpools, also to prevent footprint spam
				AdjustThirst(30)
			else
				AdjustThirst(max((B.bloodiness**2)/800,1))
		qdel(B)
	..()

/mob/living/simple_animal/hostile/abnormality/nosferatu/proc/AdjustThirst(thirst)
	blood = clamp(thirst + blood, 0, 400)
	src.adjustBruteLoss(-thirst)
	if(blood > 300 && !berzerk)
		Berzerk()

/mob/living/simple_animal/hostile/abnormality/nosferatu/proc/Berzerk()
	AdjustThirst(-300)
	animate(src, transform = matrix()*1.2, color = "#FF0000", time = 10)
	playsound(get_turf(src), 'sound/abnormalities/nosferatu/transform.ogg', 35, 8)
	bloodlust_cooldown = clamp(bloodlust_cooldown - 2, 0, 4)
	ChangeMoveToDelayBy(-1)
	berzerk = TRUE

/mob/living/simple_animal/hostile/abnormality/nosferatu/add_splatter_floor(turf/T, small_drip) //no spilling blood, it just works.
	return

//special attacks
/mob/living/simple_animal/hostile/abnormality/nosferatu/OpenFire()
	if(!can_act)
		return

	if(client)
		return

	if((banquet_cooldown < world.time) && (get_dist(src, target) < 4))
		Banquet()
		return

/mob/living/simple_animal/hostile/abnormality/nosferatu/AttackingTarget(atom/attacked_target) //Combo for double attacks
	if(!ishuman(attacked_target))
		return ..()
	var/mob/living/carbon/human/H = attacked_target
	if(bloodlust <= 0)
		bloodlust = bloodlust_cooldown
		H.deal_damage(45, BLACK_DAMAGE)
		playsound(get_turf(src), 'sound/abnormalities/nosferatu/bat_attack.ogg', 50, 1)
		to_chat(attacked_target, span_danger("The [src] attacks you savagely!"))
		AdjustThirst(40)
	else
		bloodlust -= 1
	AdjustThirst(40)
	if(SSmaptype.maptype == "limbus_labs")
		return ..()
	if(H.health < 0 || H.stat == DEAD)
		H.Drain()
	return ..()

/mob/living/simple_animal/hostile/abnormality/nosferatu/proc/BatSpawn() //stolen from titania
	playsound(get_turf(src), 'sound/abnormalities/nosferatu/batspawn.ogg', 50, 1)
	//How many we have spawned
	listclearnulls(spawned_bats)
	for(var/mob/living/L in spawned_bats)
		if(L.stat == DEAD)
			spawned_bats -= L
	if(length(spawned_bats) >= bat_spawn_limit)
		return

	//Actually spawning them
	for(var/i=bat_spawn_number, i>=0, i--)	//This counts down.
		var/mob/living/simple_animal/hostile/nosferatu_mob/B = new(get_turf(src))
		spawned_bats+=B
	addtimer(CALLBACK(src, PROC_REF(BatSpawn)), summon_cooldown_time)

/mob/living/simple_animal/hostile/abnormality/nosferatu/proc/Banquet()//AOE attack
	banquet_cooldown = world.time + banquet_cooldown_time
	can_act = FALSE
	for(var/turf/L in view(2, src))
		new /obj/effect/temp_visual/cult/sparks(L)
	playsound(get_turf(src), 'sound/abnormalities/nosferatu/special_start.ogg', 50, 0, 5)
	SLEEP_CHECK_DEATH(10)
	for(var/turf/T in view(2, src))
		var/obj/effect/temp_visual/smash_effect/bloodeffect =  new(T)
		bloodeffect.color = "#b52e19"
		for(var/mob/living/carbon/human/H in HurtInTurf(T, list(), banquet_damage, BLACK_DAMAGE, null, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE))
			if(SSmaptype.maptype == "limbus_labs")
				playsound(get_turf(src), 'sound/abnormalities/nosferatu/attack_special.ogg', 50, 0, 5)
				SLEEP_CHECK_DEATH(3)
				can_act = TRUE
				return
			if(H.health < 0)
				H.Drain()
	playsound(get_turf(src), 'sound/abnormalities/nosferatu/attack_special.ogg', 50, 0, 5)
	SLEEP_CHECK_DEATH(3)
	can_act = TRUE

//spawned mobs
/mob/living/simple_animal/hostile/nosferatu_mob
	name = "\improper Sanguine bat"
	desc = "It looks like a bat."
	icon = 'ModularTegustation/Teguicons/32x32.dmi'
	icon_state = "nosferatu_mob"
	icon_living = "nosferatu_mob"
	icon_dead = "nosferatu_mob"
	is_flying_animal = TRUE
	density = FALSE
	status_flags = MUST_HIT_PROJECTILE // Lets them be shot
	speak_emote = list("screeches")
	attack_verb_continuous = "bites"
	attack_verb_simple = "bite"
	attack_sound = 'sound/abnormalities/nosferatu/bat_attack.ogg'
	del_on_death = TRUE
	health = 300
	maxHealth = 300
	damage_coeff = list(RED_DAMAGE = 1.2, WHITE_DAMAGE = 1.8, BLACK_DAMAGE = 0.6, PALE_DAMAGE = 2)
	melee_damage_type = RED_DAMAGE
	melee_damage_lower = 5
	melee_damage_upper = 20
	move_to_delay = 1.3 //very fast, very weak.
	stat_attack = HARD_CRIT
	ranged = 1
	retreat_distance = 3
	minimum_distance = 1

/mob/living/simple_animal/hostile/nosferatu_mob/AttackingTarget(atom/attacked_target) //they spawn blood on hit
	if(ishuman(attacked_target))
		var/obj/effect/decal/cleanable/blood/B = locate() in get_turf(src)
		if(!B)
			B = new /obj/effect/decal/cleanable/blood(get_turf(src))
			B.bloodiness = 100
	return ..()

/mob/living/simple_animal/hostile/nosferatu_mob/OpenFire(atom/A)
	visible_message(span_danger("<b>[src]</b> flies around, seemingly aiming for [A]!"))
	ranged_cooldown = world.time + ranged_cooldown_time

#undef NOSFERATU_BANQUET_COOLDOWN
