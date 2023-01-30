/obj/item/part/gun
	name = "gun part"
	desc = "Spare part of gun."
	icon_state = "gun_part_1"
	spawn_tags = SPAWN_TAG_GUN_PART
	w_class = ITEM_SIZE_SMALL
	matter = list(MATERIAL_PLASTEEL = 5)
	var/generic = TRUE

/obj/item/part/gun/Initialize()
	. = ..()
	if(generic)
		icon_state = "gun_part_[rand(1,6)]"

/obj/item/part/gun/artwork
	desc = "This is an artistically-made gun part."
	spawn_frequency = 0

/obj/item/part/gun/artwork/Initialize()
	name = get_weapon_name(capitalize = TRUE)
	AddComponent(/datum/component/atom_sanity, 0.2 + pick(0,0.1,0.2), "")
	price_tag += rand(0, 500)
	return ..()

/obj/item/part/gun/artwork/get_item_cost(export)
	. = ..()
	GET_COMPONENT(comp_sanity, /datum/component/atom_sanity)
	. += comp_sanity.affect * 100

/obj/item/part/gun/modular // The type of part that supports displaying overlays when added to modular guns
	name = "modular gun part"
	desc = "Spare part of gun."
	icon_state = "gun_part_1"
	spawn_tags = SPAWN_TAG_GUN_PART
	w_class = ITEM_SIZE_SMALL
	matter = list(MATERIAL_PLASTEEL = 5)
	generic = TRUE
	var/part_overlay
	var/part_itemstring
	var/needs_grip_type
	generic = FALSE
	bad_type = /obj/item/part/gun/modular
	var/datum/component/item_upgrade/I // For changing stats when needed

/obj/item/part/gun/modular/New()
	..()
	I = AddComponent(/datum/component/item_upgrade)
	I.weapon_upgrades = list(
		UPGRADE_MAXUPGRADES = 1 // Since this takes an upgrade slot, we want to give it back
		)
	I.req_gun_tags = list(GUN_MODULAR)
	I.removable = MOD_INTEGRAL // Will get unique removal handling when we get there, until then works by disassembling the frame
	I.removal_time = WORKTIME_SLOW
	I.removal_difficulty = FAILCHANCE_NORMAL

/obj/item/part/gun/frame
	name = "gun frame"
	desc = "a generic gun frame. consider debug"
	icon_state = "frame_olivaw"
	generic = FALSE
	bad_type = /obj/item/part/gun/frame
	matter = list(MATERIAL_PLASTEEL = 5)
	rarity_value = 10

	// What gun the frame makes when it only accepts one grip
	var/result = /obj/item/gun/projectile

	// Currently installed grip
	var/obj/item/part/gun/modular/grip/InstalledGrip

	// Which grips does the frame accept?
	var/list/gripvars = list(/obj/item/part/gun/modular/grip/wood, /obj/item/part/gun/modular/grip/black)
	// What are the results (in order relative to gripvars)?
	var/list/resultvars = list(/obj/item/gun/projectile, /obj/item/gun/energy)

	// Currently installed mechanism
	var/obj/item/part/gun/modular/grip/InstalledMechanism
	// Which mechanism the frame accepts?
	var/list/mechanismvar = /obj/item/part/gun/modular/mechanism

	// Currently installed barrel
	var/obj/item/part/gun/modular/barrel/InstalledBarrel
	// Which barrels does the frame accept?
	var/list/barrelvars = list(/obj/item/part/gun/modular/barrel)

	var/serial_type = ""

/obj/item/part/gun/frame/New(loc, ...)
	. = ..()
	var/obj/item/gun/G = new result(null)
	if(G.serial_type)
		serial_type = G.serial_type

/obj/item/part/gun/frame/New(loc)
	..()
	var/spawn_with_preinstalled_parts = FALSE
	if(istype(loc, /obj/structure/scrap_spawner))
		spawn_with_preinstalled_parts = TRUE
	else if(in_maintenance())
		var/turf/T = get_turf(src)
		for(var/atom/A in T.contents)
			if(istype(A, /obj/spawner))
				spawn_with_preinstalled_parts = TRUE

	if(spawn_with_preinstalled_parts)
		var/list/parts_list = list("mechanism", "barrel", "grip")

		pick_n_take(parts_list)
		if(prob(50))
			pick_n_take(parts_list)

		for(var/part in parts_list)
			switch(part)
				if("mechanism")
					InstalledMechanism = new mechanismvar(src)
				if("barrel")
					var/select = pick(barrelvars)
					InstalledBarrel = new select(src)
				if("grip")
					var/select = pick(gripvars)
					InstalledGrip = new select(src)
					var/variantnum = gripvars.Find(select)
					result = resultvars[variantnum]

/obj/item/part/gun/frame/attackby(obj/item/I, mob/living/user, params)
	if(istype(I, /obj/item/part/gun/modular/grip))
		if(InstalledGrip)
			to_chat(user, SPAN_WARNING("[src] already has a grip attached!"))
			return
		else
			handle_gripvar(I, user)

	if(istype(I, /obj/item/part/gun/modular/mechanism))
		if(InstalledMechanism)
			to_chat(user, SPAN_WARNING("[src] already has a mechanism attached!"))
			return
		else
			handle_mechanismvar(I, user)

	if(istype(I, /obj/item/part/gun/modular/barrel))
		if(InstalledBarrel)
			to_chat(user, SPAN_WARNING("[src] already has a barrel attached!"))
			return
		else
			handle_barrelvar(I, user)

	var/tool_type = I.get_tool_type(user, list(QUALITY_SCREW_DRIVING, serial_type ? QUALITY_HAMMERING : null), src)
	switch(tool_type)
		if(QUALITY_HAMMERING)
			user.visible_message(SPAN_NOTICE("[user] begins scribbling \the [name]'s gun serial number away."), SPAN_NOTICE("You begin removing the serial number from \the [name]."))
			if(I.use_tool(user, src, WORKTIME_SLOW, QUALITY_HAMMERING, FAILCHANCE_EASY, required_stat = STAT_MEC))
				user.visible_message(SPAN_DANGER("[user] removes \the [name]'s gun serial number."), SPAN_NOTICE("You successfully remove the serial number from \the [name]."))
				serial_type = null
				return

		if(QUALITY_SCREW_DRIVING)
			var/list/possibles = contents.Copy()
			var/obj/item/part/gun/toremove = input("Which part would you like to remove?","Removing parts") in possibles
			if(!toremove)
				return
			if(I.use_tool(user, src, WORKTIME_INSTANT, QUALITY_SCREW_DRIVING, FAILCHANCE_ZERO, required_stat = STAT_MEC))
				eject_item(toremove, user)
				if(istype(toremove, /obj/item/part/gun/modular/grip))
					InstalledGrip = null
				else if(istype(toremove, /obj/item/part/gun/modular/barrel))
					InstalledBarrel = FALSE
				else if(istype(toremove, /obj/item/part/gun/modular/mechanism))
					InstalledMechanism = FALSE

	return ..()

/obj/item/part/gun/frame/proc/handle_gripvar(obj/item/I, mob/living/user)
	if(I.type in gripvars)
		if(insert_item(I, user))
			var/variantnum = gripvars.Find(I.type)
			result = resultvars[variantnum]
			InstalledGrip = I
			to_chat(user, SPAN_NOTICE("You have attached the grip to \the [src]."))
			return
	else
		to_chat(user, SPAN_WARNING("This grip does not fit!"))
		return

/obj/item/part/gun/frame/proc/handle_mechanismvar(obj/item/I, mob/living/user)
	if(I.type == mechanismvar)
		if(insert_item(I, user))
			InstalledMechanism = I
			to_chat(user, SPAN_NOTICE("You have attached the mechanism to \the [src]."))
			return
	else
		to_chat(user, SPAN_WARNING("This mechanism does not fit!"))
		return

/obj/item/part/gun/frame/proc/handle_barrelvar(obj/item/I, mob/living/user)
	if(I.type in barrelvars)
		if(insert_item(I, user))
			InstalledBarrel = I
			to_chat(user, SPAN_NOTICE("You have attached the barrel to \the [src]."))
			return
	else
		to_chat(user, SPAN_WARNING("This barrel does not fit!"))
		return

/obj/item/part/gun/frame/attack_self(mob/user)
	. = ..()
	var/turf/T = get_turf(src)
	if(!InstalledGrip)
		to_chat(user, SPAN_WARNING("\the [src] does not have a grip!"))
		return
	if(!InstalledMechanism)
		to_chat(user, SPAN_WARNING("\the [src] does not have a mechanism!"))
		return
	if(!InstalledBarrel)
		to_chat(user, SPAN_WARNING("\the [src] does not have a barrel!"))
		return
	var/obj/item/gun/G = new result(T)
	G.serial_type = serial_type
	if(barrelvars.len > 1 && istype(G, /obj/item/gun/projectile))
		var/obj/item/gun/projectile/P = G
		P.caliber = InstalledBarrel.caliber
		G.gun_parts = list(src.type = 1, InstalledGrip.type = 1, InstalledMechanism.type = 1, InstalledBarrel.type = 1)
	qdel(src)
	return

/obj/item/part/gun/frame/examine(user, distance)
	. = ..()
	if(.)
		if(InstalledGrip)
			to_chat(user, SPAN_NOTICE("\the [src] has \a [InstalledGrip] installed."))
		else
			to_chat(user, SPAN_NOTICE("\the [src] does not have a grip installed."))
		if(InstalledMechanism)
			to_chat(user, SPAN_NOTICE("\the [src] has \a [InstalledMechanism] installed."))
		else
			to_chat(user, SPAN_NOTICE("\the [src] does not have a mechanism installed."))
		if(InstalledBarrel)
			to_chat(user, SPAN_NOTICE("\the [src] has \a [InstalledBarrel] installed."))
		else
			to_chat(user, SPAN_NOTICE("\the [src] does not have a barrel installed."))
		if(in_range(user, src) || isghost(user))
			if(serial_type)
				to_chat(user, SPAN_WARNING("There is a serial number on the frame, it reads [serial_type]."))
			else if(isnull(serial_type))
				to_chat(user, SPAN_DANGER("The serial is scribbled away."))

//Grips
/obj/item/part/gun/modular/grip
	name = "generic grip"
	desc = "A generic firearm grip, unattached from a firearm."
	icon_state = "grip_wood"
	generic = FALSE
	bad_type = /obj/item/part/gun/modular/grip
	matter = list(MATERIAL_PLASTIC = 6)
	price_tag = 100
	rarity_value = 5
	var/type_of_grip = "wood" // Placeholder
	part_itemstring = TRUE

/obj/item/part/gun/modular/grip/New()
	..()
	I.weapon_upgrades[GUN_UPGRADE_DEFINE_GRIP] = type_of_grip
	I.weapon_upgrades[GUN_UPGRADE_OFFSET] = -15 // Without a grip the gun shoots funny, players are legally allowed to not use a grip
	I.gun_loc_tag = PART_GRIP

/obj/item/part/gun/modular/grip/wood
	name = "wood grip"
	desc = "A wood firearm grip, unattached from a firearm."
	icon_state = "grip_wood"
	matter = list(MATERIAL_WOOD = 5)
	part_overlay = "grip_wood"
	type_of_grip = "wood"

/obj/item/part/gun/modular/grip/black //Nanotrasen, Moebius, Syndicate, Oberth
	name = "plastic grip"
	desc = "A black plastic firearm grip, unattached from a firearm. For sleekness and decorum."
	icon_state = "grip_black"
	part_overlay = "grip_black"
	type_of_grip = "black"

/obj/item/part/gun/modular/grip/rubber //FS and IH
	name = "rubber grip"
	desc = "A rubber firearm grip, unattached from a firearm. For professionalism and violence of action."
	icon_state = "grip_rubber"
	part_overlay = "grip_rubber"
	type_of_grip = "rubber"

/obj/item/part/gun/modular/grip/excel
	name = "Excelsior plastic grip"
	desc = "A tan plastic firearm grip, unattached from a firearm. To fight for Haven and to spread the unified revolution!"
	icon_state = "grip_excel"
	rarity_value = 7
	part_overlay = "grip_excelsior"
	type_of_grip = "excelsior"

/obj/item/part/gun/modular/grip/serb
	name = "bakelite plastic grip"
	desc = "A brown plastic firearm grip, unattached from a firearm. Classics never go out of style."
	icon_state = "grip_serb"
	rarity_value = 7
	part_overlay = "grip_serbian"
	type_of_grip = "serbian"

//Mechanisms
/obj/item/part/gun/modular/mechanism
	name = "generic mechanism"
	desc = "All the bits that makes the bullet go bang."
	icon_state = "mechanism_pistol"
	generic = FALSE
	bad_type = /obj/item/part/gun/modular/mechanism
	matter = list(MATERIAL_PLASTEEL = 5)
	price_tag = 100
	rarity_value = 6
	var/list/accepted_calibers = list(CAL_PISTOL, CAL_MAGNUM, CAL_SRIFLE, CAL_CLRIFLE, CAL_LRIFLE, CAL_SHOTGUN)
	var/mag_well = MAG_WELL_GENERIC

/obj/item/part/gun/modular/mechanism/New()
	..()
	I.weapon_upgrades[GUN_UPGRADE_DEFINE_MAG_WELL] = mag_well
	I.weapon_upgrades[GUN_UPGRADE_DEFINE_OK_CALIBERS] = accepted_calibers
	I.gun_loc_tag = PART_MECHANISM

/obj/item/part/gun/modular/mechanism/pistol
	name = "pistol mechanism"
	desc = "All the bits that makes the bullet go bang, all in a small, convenient frame."
	icon_state = "mechanism_pistol"
	mag_well = MAG_WELL_PISTOL|MAG_WELL_H_PISTOL

/obj/item/part/gun/modular/mechanism/revolver
	name = "revolver mechanism"
	desc = "All the bits that makes the bullet go bang, rolling round and round."
	icon_state = "mechanism_revolver"

/obj/item/part/gun/modular/mechanism/shotgun
	name = "shotgun mechanism"
	desc = "All the bits that makes the bullet go bang, perfect for long shells."
	icon_state = "mechanism_shotgun"
	matter = list(MATERIAL_PLASTEEL = 10)
	mag_well = MAG_WELL_RIFLE

/obj/item/part/gun/modular/mechanism/smg
	name = "SMG mechanism"
	desc = "All the bits that makes the bullet go bang, in a speedy package."
	icon_state = "mechanism_smg"
	mag_well = MAG_WELL_SMG

/obj/item/part/gun/modular/mechanism/autorifle
	name = "self-loading mechanism"
	desc = "All the bits that makes the bullet go bang, for all the military hardware you know and love."
	icon_state = "mechanism_autorifle"
	matter = list(MATERIAL_PLASTEEL = 10)
	mag_well = MAG_WELL_RIFLE|MAG_WELL_RIFLE_L|MAG_WELL_RIFLE_D

/obj/item/part/gun/modular/mechanism/autorifle/burst
	name = "self-loading mechanism"
	desc = "All the bits that makes the bullet go bang, for all the military hardware you know and love."
	icon_state = "mechanism_autorifle"
	matter = list(MATERIAL_PLASTEEL = 10)
	mag_well = MAG_WELL_RIFLE|MAG_WELL_RIFLE_L|MAG_WELL_RIFLE_D

/obj/item/part/gun/modular/mechanism/autorifle/burst/New()
	..()
	I.weapon_upgrades[GUN_UPGRADE_FIREMODES] = list(BURST_3_ROUND, BURST_5_ROUND)

/obj/item/part/gun/modular/mechanism/autorifle/fullauto
	name = "self-loading mechanism"
	desc = "All the bits that makes the bullet go bang, for all the military hardware you know and love."
	icon_state = "mechanism_autorifle"
	matter = list(MATERIAL_PLASTEEL = 10)
	mag_well = MAG_WELL_RIFLE|MAG_WELL_RIFLE_L|MAG_WELL_RIFLE_D

/obj/item/part/gun/modular/mechanism/autorifle/fullauto/New()
	..()
	I.weapon_upgrades[GUN_UPGRADE_FIREMODES] = list(BURST_3_ROUND, BURST_5_ROUND, FULL_AUTO_400)

// Determined - slower firerate, but no loss in damage. Total point value: +3
/obj/item/part/gun/modular/mechanism/autorifle/determined
	name = "self-loading mechanism"
	desc = "All the bits that makes the bullet go bang, for all the military hardware you know and love."
	icon_state = "mechanism_autorifle"
	matter = list(MATERIAL_PLASTEEL = 10)
	list/accepted_calibers = list(CAL_SRIFLE, CAL_CLRIFLE, CAL_LRIFLE)
	mag_well = MAG_WELL_RIFLE|MAG_WELL_RIFLE_L|MAG_WELL_RIFLE_D

/obj/item/part/gun/modular/mechanism/autorifle/determined/New()
	..()
	I.weapon_upgrades[GUN_UPGRADE_FIREMODES] = list(BURST_3_ROUND, FULL_AUTO_300) // +5 points
	I.weapon_upgrades[GUN_UPGRADE_RECOIL] = 1.25 // -2 points

/obj/item/part/gun/modular/mechanism/machinegun
	name = "machine gun mechanism"
	desc = "All the bits that makes the bullet go bang. Now I have a machine gun, Ho, Ho, Ho."
	icon_state = "mechanism_machinegun"
	matter = list(MATERIAL_PLASTEEL = 16)
	rarity_value = 8
	mag_well = MAG_WELL_BOX

// steel mechanisms
/obj/item/part/gun/modular/mechanism/pistol/steel
	name = "cheap pistol mechanism"
	desc = "All the bits that makes the bullet go bang, all in a small, convenient frame. \
			This one does not look as high quality."
	matter = list(MATERIAL_STEEL = 3)

/obj/item/part/gun/modular/mechanism/revolver/steel
	name = "cheap revolver mechanism"
	desc = "All the bits that makes the bullet go bang, rolling round and round. \
			This one does not look as high quality."
	matter = list(MATERIAL_STEEL = 3)

/obj/item/part/gun/modular/mechanism/shotgun/steel
	name = "cheap shotgun mechanism"
	desc = "All the bits that makes the bullet go bang, perfect for long shells.  \
			This one does not look as high quality."
	matter = list(MATERIAL_STEEL = 3)

/obj/item/part/gun/modular/mechanism/smg/steel
	name = "cheap SMG mechanism"
	desc = "All the bits that makes the bullet go bang, in a speedy package. \
			This one does not look as high quality."
	matter = list(MATERIAL_STEEL = 3)

/obj/item/part/gun/modular/mechanism/boltgun // fits better in this category despite not being a steel variant
	name = "manual-action mechanism"
	desc = "All the bits that makes the bullet go bang, slow and methodical."
	icon_state = "mechanism_boltaction"
	matter = list(MATERIAL_STEEL = 3)

/obj/item/part/gun/modular/mechanism/autorifle/steel
	name = "cheap self-loading mechanism"
	desc = "All the bits that makes the bullet go bang, for all the military hardware you know and love. \
			This one does not look as high quality."
	matter = list(MATERIAL_STEEL = 10)

//Barrels
/obj/item/part/gun/modular/barrel
	name = "generic barrel"
	desc = "A gun barrel, which keeps the bullet going in the right direction."
	icon_state = "barrel_35"
	generic = FALSE
	bad_type = /obj/item/part/gun/modular/barrel
	matter = list(MATERIAL_PLASTEEL = 8)
	price_tag = 200
	rarity_value = 15
	var/caliber = CAL_357

/obj/item/part/gun/modular/barrel/New()
	..()
	I.weapon_upgrades[GUN_UPGRADE_DEFINE_CALIBER] = caliber
	I.gun_loc_tag = PART_BARREL

/obj/item/part/gun/modular/barrel/pistol
	name = ".35 barrel"
	desc = "A gun barrel, which keeps the bullet going in the right direction. Chambered in .35 caliber."
	icon_state = "barrel_35"
	matter = list(MATERIAL_PLASTEEL = 4)
	price_tag = 100
	caliber = CAL_PISTOL
	part_overlay = "well_pistol"

/obj/item/part/gun/modular/barrel/magnum
	name = ".40 barrel"
	desc = "A gun barrel, which keeps the bullet going in the right direction. Chambered in .40 caliber."
	icon_state = "barrel_40"
	matter = list(MATERIAL_PLASTEEL = 4)
	price_tag = 100
	caliber = CAL_MAGNUM
	part_overlay = "well_magnum"

/obj/item/part/gun/modular/barrel/magnum/New()

/obj/item/part/gun/modular/barrel/srifle
	name = ".20 barrel"
	desc = "A gun barrel, which keeps the bullet going in the right direction. Chambered in .20 caliber."
	icon_state = "barrel_20"
	matter = list(MATERIAL_PLASTEEL = 8)
	caliber = CAL_SRIFLE
	part_overlay = "well_srifle"

/obj/item/part/gun/modular/barrel/clrifle
	name = ".25 barrel"
	desc = "A gun barrel, which keeps the bullet going in the right direction. Chambered in .25 caliber."
	icon_state = "barrel_25"
	matter = list(MATERIAL_PLASTEEL = 8)
	caliber = CAL_CLRIFLE
	part_overlay = "well_clrifle"

/obj/item/part/gun/modular/barrel/lrifle
	name = ".30 barrel"
	desc = "A gun barrel, which keeps the bullet going in the right direction. Chambered in .30 caliber."
	icon_state = "barrel_30"
	matter = list(MATERIAL_PLASTEEL = 8)
	caliber = CAL_LRIFLE
	part_overlay = "well_lrifle"

/obj/item/part/gun/modular/barrel/shotgun
	name = "shotgun barrel"
	desc = "A gun barrel, which keeps the bullet (or bullets) going in the right direction. Chambered in .50 caliber."
	icon_state = "barrel_50"
	matter = list(MATERIAL_PLASTEEL = 8)
	caliber = CAL_SHOTGUN
	part_overlay = "well_shotgun"

/obj/item/part/gun/modular/barrel/antim
	name = ".60 barrel"
	desc = "A gun barrel, which keeps the bullet going in the right direction. Chambered in .60 caliber."
	icon_state = "barrel_60"
	matter = list(MATERIAL_PLASTEEL = 16)
	caliber = CAL_ANTIM
	part_overlay = "well_amr"

// steel barrels
/obj/item/part/gun/modular/barrel/pistol/steel
	name = "cheap .35 barrel"
	desc = "A gun barrel, which keeps the bullet going in the right direction. Chambered in .35 caliber. \
			This one does not look as high quality."
	matter = list(MATERIAL_STEEL = 2)

/obj/item/part/gun/modular/barrel/magnum/steel
	name = "cheap .40 barrel"
	desc = "A gun barrel, which keeps the bullet going in the right direction. Chambered in .40 caliber. \
			This one does not look as high quality."
	matter = list(MATERIAL_STEEL = 2)

/obj/item/part/gun/modular/barrel/srifle/steel
	name = "cheap .20 barrel"
	desc = "A gun barrel, which keeps the bullet going in the right direction. Chambered in .20 caliber. \
			 This one does not look as high quality."
	matter = list(MATERIAL_STEEL = 5)

/obj/item/part/gun/modular/barrel/clrifle/steel
	name = "cheap .25 barrel"
	desc = "A gun barrel, which keeps the bullet going in the right direction. Chambered in .25 caliber. \
			This one does not look as high quality."
	matter = list(MATERIAL_STEEL = 5)

/obj/item/part/gun/modular/barrel/lrifle/steel
	name = "cheap .30 barrel"
	desc = "A gun barrel, which keeps the bullet going in the right direction. Chambered in .30 caliber. \
			This one does not look as high quality."
	matter = list(MATERIAL_STEEL = 5)

/obj/item/part/gun/modular/barrel/shotgun/steel
	name = "cheap shotgun barrel"
	desc = "A gun barrel, which keeps the bullet (or bullets) going in the right direction. Chambered in .50 caliber. \
			This one does not look as high quality."
	matter = list(MATERIAL_STEEL = 2)

/obj/item/part/gun/modular/stock
	name = "stock frame"
	desc = "A frame for the stock of a gun. Not compatible with most gun frames. Improves accuracy when the weapon is wielded in two hands, but increases bulk."
	matter = list(MATERIAL_STEEL = 10)
	icon_state = "stock_frame"
	generic = FALSE
	part_overlay = "stock"
	needs_grip_type = TRUE

/obj/item/part/gun/modular/stock/New()
	..()
	I.weapon_upgrades[GUN_UPGRADE_DEFINE_STOCK] = TRUE
	I.gun_loc_tag = PART_STOCK
