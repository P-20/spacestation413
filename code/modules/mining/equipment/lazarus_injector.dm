/**********************Lazarus Injector**********************/
/obj/item/lazarus_injector
	name = "lazarus injector"
	desc = "An injector with a cocktail of nanomachines and chemicals, this device can seemingly raise animals from the dead, making them become friendly to the user. Unfortunately, the process is useless on higher forms of life and incredibly costly, so these were hidden in storage until an executive thought they'd be great motivation for some of their employees."
	icon = 'icons/obj/syringe.dmi'
	icon_state = "lazarus_hypo"
	item_state = "hypo"
	lefthand_file = 'icons/mob/inhands/equipment/medical_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/medical_righthand.dmi'
	throwforce = 0
	w_class = WEIGHT_CLASS_SMALL
	throw_speed = 3
	throw_range = 5
	var/loaded = 1
	var/malfunctioning = 0
	var/revive_type = SENTIENCE_ORGANIC //So you can't revive boss monsters or robots with it

/obj/item/lazarus_injector/afterattack(atom/target, mob/user, proximity_flag)
	if(!loaded)
		return
	if(isliving(target) && proximity_flag)
		if(isanimal(target))
			var/mob/living/simple_animal/M = target
			if(M.sentience_type != revive_type)
				to_chat(user, "<span class='info'>[src] does not work on this sort of creature.</span>")
				return
			if(M.stat == DEAD)
				M.faction = list("neutral")
				M.revive(full_heal = 1, admin_revive = 1)
				if(ishostile(target))
					var/mob/living/simple_animal/hostile/H = M
					if(malfunctioning)
						H.faction |= list("lazarus", "[REF(user)]")
						H.robust_searching = 1
						H.friends += user
						H.attack_same = 1
						log_game("[user] has revived hostile mob [target] with a malfunctioning lazarus injector")
					else
						H.attack_same = 0
				loaded = 0
				user.visible_message("<span class='notice'>[user] injects [M] with [src], reviving it.</span>")
				SSblackbox.record_feedback("tally", "lazarus_injector", 1, M.type)
				playsound(src,'sound/effects/refill.ogg',50,1)
				icon_state = "lazarus_empty"
				return
			else
				to_chat(user, "<span class='info'>[src] is only effective on the dead.</span>")
				return
		else
			to_chat(user, "<span class='info'>[src] is only effective on lesser beings.</span>")
			return

/obj/item/lazarus_injector/emp_act()
	if(!malfunctioning)
		malfunctioning = 1

/obj/item/lazarus_injector/examine(mob/user)
	..()
	if(!loaded)
		to_chat(user, "<span class='info'>[src] is empty.</span>")
	if(malfunctioning)
		to_chat(user, "<span class='info'>The display on [src] seems to be flickering.</span>")


/*********************Mob Capsule*************************/
// ported from /vg/station by Difarem, december 2017

/obj/item/device/mobcapsule
	name = "lazarus capsule"
	desc = "It allows you to store and deploy lazarus-injected creatures easier."
	icon = 'icons/obj/mobcap.dmi'
	icon_state = "mobcap0"
	w_class = WEIGHT_CLASS_SMALL
	throwforce = 00
	throw_speed = 4
	throw_range = 20
	force = 0
	materials = list(MAT_METAL = 100)
	var/storage_capacity = 1
	var/mob/living/capsuleowner = null
	var/tripped = 0
	var/colorindex = 0
	var/mob/contained_mob

/obj/item/device/mobcapsule/attackby(obj/item/W, mob/user, params)
	if(contained_mob != null && istype(W, /obj/item/pen))
		if(user != capsuleowner)
			to_chat(user, "<span class='warning'>\The [src] briefly flashes an error.</span>")
			return 0
		spawn()
			var/mname = sanitize(input("Choose a name for your friend.", "Name your friend", contained_mob.name) as text|null)
			if(mname)
				contained_mob.name = mname
				to_chat(user, "<span class='notice'>Renaming successful, say hello to [contained_mob]!</span>")
				name = "lazarus capsule - [mname]"
	..()

/obj/item/device/mobcapsule/attack_self(mob/user)
	colorindex += 1
	if(colorindex >= 6)
		colorindex = 0
	icon_state = "mobcap[colorindex]"
	update_icon()

/obj/item/device/mobcapsule/pickup(mob/user)
	tripped = 0
	capsuleowner = user

/obj/item/device/mobcapsule/throw_impact(atom/target, datum/thrownthing/throwinfo)
	if(!tripped)
		if(contained_mob)
			dump_contents(throwinfo.thrower)
			tripped = 1
		else
			take_contents(target, throwinfo.thrower)
			tripped = 1
	..()

/obj/item/device/mobcapsule/proc/dump_contents(mob/user)
	if(contained_mob)
		contained_mob.forceMove(src.loc)

		var/turf/turf = get_turf(src)
		log_attack("[key_name(user)] has released hostile mob [contained_mob] with a capsule in area [turf.loc] ([x],[y],[z]).")
		//contained_mob.attack_log += "\[[time_stamp()]\] Released by <b>[key_name(user)]</b> in area [turf.loc] ([x],[y],[z])."
		//user.attack_log += "\[[time_stamp()]\] Released hostile mob <b>[contained_mob]</b> in area [turf.loc] ([x],[y],[z])."
		//msg_admin_attack("[key_name(user)] has released hostile mob [contained_mob] with a capsule in area [turf.loc] ([x],[y],[z]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[x];Y=[y];Z=[z]'>JMP</A>).")

		if(contained_mob.client)
			contained_mob.client.eye = contained_mob.client.mob
			contained_mob.client.perspective = MOB_PERSPECTIVE
		contained_mob = null
		name = "lazarus capsule"

/obj/item/device/mobcapsule/proc/take_contents(atom/target, mob/user)
	var/mob/living/simple_animal/AM = target
	if(istype(AM))
		var/mob/living/simple_animal/M = AM
		var/mob/living/simple_animal/hostile/H = M
		if(istype(H))
			for(var/things in H.friends)
				if(capsuleowner in H.friends)
					if(insert(AM, user) == -1) //Limit reached
						break
		else
			insert(AM, user) // allows non-hostile mobs to be captured, might disable this

/obj/item/device/mobcapsule/proc/insert(var/atom/movable/AM, mob/user)
	if(contained_mob)
		return -1

	if(istype(AM, /mob/living))
		var/mob/living/L = AM
		//if(L.locked_to)
			//return 0
		if(L.client)
			L.client.perspective = EYE_PERSPECTIVE
			L.client.eye = src
	else if(!istype(AM, /obj/item) && !istype(AM, /obj/effect/dummy/chameleon))
		return 0
	else if(AM.density || AM.anchored)
		return 0
	AM.forceMove(src)
	contained_mob = AM
	name = "lazarus capsule - [AM.name]"
	return 1
