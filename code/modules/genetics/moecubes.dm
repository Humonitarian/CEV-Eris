/obj/item/reagent_containers/food/snacks/moecube
	name = "cube of twitching meat"
	desc = "Absolutely disgusting."
	icon = 'icons/obj/eris_genetics.dmi'
	icon_state = "genecube"
	layer = TOP_ITEM_LAYER // So it don't "fall" under machine that spawned it
	spawn_blacklisted = TRUE
	var/gene_type
	var/gene_value

	filling_color = "#5C4033"
	preloaded_reagents = list("moeball" = 5, "protein" = 3)
	bitesize = 4
	taste_tag = list(MEAT_FOOD, UMAMI_FOOD)

/obj/item/reagent_containers/food/snacks/moecube/proc/set_genes()
	for(var/datum/reagent/toxin/mutagen/moeball/MT in reagents.reagent_list)
		MT.gene_type = gene_type
		MT.gene_value = gene_value
		if(name == "cube of whirling worms")
			MT.isWorm()

/obj/item/reagent_containers/food/snacks/moecube/worm
	name = "cube of whirling worms"
	icon_state = "wormcube"

	filling_color = "#d49b81"
	taste_tag = list(UMAMI_FOOD, INSECTS_FOOD)
