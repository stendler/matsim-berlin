

JAR := matsim-berlin-*.jar
V := v6.0
CRS := EPSG:25832

p := input/$V
germany := ../shared-svn/projects/matsim-germany
berlin := ../public-svn/matsim/scenarios/countries/de/berlin/berlin-$V

MEMORY ?= 20G
REGIONS := brandenburg
SHP_FILES=$(patsubst %, input/shp/%-latest-free.shp.zip, $(REGIONS))

osmosis := osmosis/bin/osmosis

# Scenario creation tool
sc := java -Xmx$(MEMORY) -cp $(JAR) org.matsim.synthetic.RunOpenBerlinCalibration

.PHONY: prepare

$(JAR):
	mvn package

${SHP_FILES}:
	mkdir -p input/shp
	curl https://download.geofabrik.de/europe/germany/$(@:input/shp/%=%) -o $@

input/brandenburg.osm.pbf:
	curl https://download.geofabrik.de/europe/germany/brandenburg-230101.osm.pbf -o $@


$(germany)/RegioStaR-Referenzdateien.xlsx:
	curl https://mcloud.de/downloads/mcloud/536149D1-2902-4975-9F7D-253191C0AD07/RegioStaR-Referenzdateien.xlsx -o $@

input/landuse.shp: ${SHP_FILES}
	mkdir -p input/landuse
	$(sc) prepare create-landuse-shp $^\
	 --target-crs ${CRS}\
	 --output $@

input/facilities.shp: input/brandenburg.osm.pbf
	$(sc) prepare facility-shp\
	 --activity-mapping input/activity_mapping.json\
	 --input $<\
	 --output $@


input/PLR_2013_2020.csv:
	curl https://instantatlas.statistik-berlin-brandenburg.de/instantatlas/interaktivekarten/kommunalatlas/Kommunalatlas.zip --insecure -o atlas.zip
	unzip atlas.zip -d input
	rm atlas.zip

$(berlin)/input/shp/Planungsraum_EPSG_25833.shp:
	curl https://www.stadtentwicklung.berlin.de/planen/basisdaten_stadtentwicklung/lor/download/LOR_SHP_EPSG_25833.zip -o tmp.zip
	unzip tmp.zip -d $(berlin)/input
	rm tmp.zip


input/network.osm: input/brandenburg.osm.pbf

	$(osmosis) --rb file=$<\
	 --tf accept-ways highway=motorway,motorway_link,trunk,trunk_link,primary,primary_link,secondary_link,secondary,tertiary,motorway_junction,residential\
	 --bounding-polygon file="$p/area/area.poly"\
	 --used-node --wb input/network-detailed.osm.pbf

	$(osmosis) --rb file=$<\
	 --tf accept-ways highway=motorway,motorway_link,trunk,trunk_link,primary,primary_link,secondary_link,secondary,tertiary,motorway_junction\
	 --used-node --wb input/network-coarse.osm.pbf

	$(osmosis) --rb file=input/network-coarse.osm.pbf --rb file=input/network-detailed.osm.pbf\
  	 --merge\
  	 --tag-transform file=input/remove-railway.xml\
  	 --wx $@

	rm input/network-detailed.osm.pbf
	rm input/network-coarse.osm.pbf


input/sumo.net.xml: input/network.osm

	$(SUMO_HOME)/bin/netconvert --geometry.remove --ramps.guess --ramps.no-split\
	 --type-files $(SUMO_HOME)/data/typemap/osmNetconvert.typ.xml,$(SUMO_HOME)/data/typemap/osmNetconvertUrbanDe.typ.xml\
	 --tls.guess-signals true --tls.discard-simple --tls.join --tls.default-type actuated\
	 --junctions.join --junctions.corner-detail 5\
	 --roundabouts.guess --remove-edges.isolated\
	 --no-internal-links --keep-edges.by-vclass passenger\
	 --remove-edges.by-vclass hov,tram,rail,rail_urban,rail_fast,pedestrian,bicycle\
	 --output.original-names --output.street-names\
	 --proj "+proj=utm +zone=32 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"\
	 --osm-files $< -o=$@


$p/berlin-$V-network.xml.gz: #input/sumo.net.xml
	# Use 5.x network
	$(sc) prepare reproject-network\
	 --input $(berlin)/../berlin-v5.5-10pct/input/berlin-v5.5-network.xml.gz\
	 --transit-schedule $(berlin)/../berlin-v5.5-10pct/input/berlin-v5.5-transit-schedule.xml.gz\
	 --output $@\
 	 --output-transit $p/berlin-v6.0-transitSchedule.xml.gz\
	 --input-crs EPSG:31468\
	 --target-crs $(CRS)

#	$(sc) prepare network-from-sumo $<\
	 --output $@

#	$(sc) prepare clean-network $@ --output $@ --modes car

$p/berlin-$V-network-with-pt.xml.gz: $p/berlin-$V-network.xml.gz

	# Copy 5.x network stuff
	cp $< $@
	cp $(berlin)/../berlin-v5.5-10pct/input/berlin-v5.5-transit-vehicles.xml.gz $p/berlin-v6.0-transitVehicles.xml.gz

#	$(sc) prepare transit-from-gtfs --network $< --output=$p\
	 --name berlin-$V --date "2023-01-11" --target-crs $(CRS) \
	 ../shared-svn/projects/DiTriMo/data/gtfs/20230113_regio.zip\
	 ../shared-svn/projects/DiTriMo/data/gtfs/20230113_train_short.zip\
	 ../shared-svn/projects/DiTriMo/data/gtfs/20230113_train_long.zip\
	 --prefix regio_,short_,long_\
	 --shp $p/area/area.shp\
	 --shp $p/area/area.shp\
	 --shp $p/area/area.shp

# TODO: naming scheme must be updated
$p/berlin-$V-car-counts.xml.gz: $p/berlin-$V-network.xml.gz
	$(sc) prepare create-counts\
	 --network $<\
	 --shp $(berlin)/Verkehrsmengen_DTVw_2019.zip\
	 --output $p/berlin-$V-
	# TODO: output argument not ideal


$p/berlin-$V-counts-car-vmz.xml.gz:
	$(sc) prepare counts-from-vmz\
	 --csv ../shared-svn/projects/matsim-berlin/berlin-v5.5/original_data/vmz_counts_2018/CountsId_to_linkId.csv\
	 --excel ../shared-svn/projects/matsim-berlin/berlin-v5.5/original_data/vmz_counts_2018/Datenexport_2018_TU_Berlin.xlsx\
 	 --output $@

$p/berlin-$V-facilities.xml.gz: $p/berlin-$V-network.xml.gz input/facilities.shp
	$(sc) prepare facilities --network $< --shp $(word 2,$^)\
	 --output $@

$p/berlin-only-$V-25pct.plans.xml.gz: input/PLR_2013_2020.csv $(berlin)/input/shp/Planungsraum_EPSG_25833.shp input/landuse.shp
	$(sc) prepare berlin-population\
		--input $<\
		--shp $(word 2,$^) --shp-crs EPSG:25833\
		--landuse $(word 3,$^) --landuse-filter residential\
		--output $@


$p/brandeburg-only-$V-25pct.plans.xml.gz: input/landuse.shp
	$(sc) prepare brandenburg-population\
	 --shp $(germany)/vg5000/vg5000_ebenen_0101/VG5000_GEM.shp\
	 --population $(germany)/regionalstatistik/population.csv\
	 --employees $(germany)/regionalstatistik/employed.json\
 	 --landuse $< --landuse-filter residential\
 	 --output $@

$p/berlin-static-$V-25pct.plans.xml.gz: $p/berlin-only-$V-25pct.plans.xml.gz $p/brandeburg-only-$V-25pct.plans.xml.gz
	$(sc) prepare merge-populations $^\
	 --output $@

	$(sc) prepare lookup-regiostar --input $@ --output $@ --xls $(germany)/RegioStaR-Referenzdateien.xlsx

	$(sc) prepare assign-commuters\
	 --shp $(germany)/vg5000/vg5000_ebenen_0101/VG5000_GEM.shp\
	 --commuter $(germany)/regionalstatistik/commuter.csv\
	 --input $@ --output $@

	# For debugging and visualization
	$(sc) prepare downsample-population $@\
     	 --sample-size 0.25\
     	 --samples 0.1\


$p/berlin-activities-$V-25pct.plans-1.xml.gz: $p/berlin-static-$V-25pct.plans.xml.gz
	# Create five separate sets of activities
	$(sc) prepare activity-sampling --seed 2 --input $< --output $(subst plans-1,plans-2,$@) --persons src/main/python/table-persons.csv --activities src/main/python/table-activities.csv
	$(sc) prepare activity-sampling --seed 3 --input $< --output $(subst plans-1,plans-3,$@) --persons src/main/python/table-persons.csv --activities src/main/python/table-activities.csv
	$(sc) prepare activity-sampling --seed 4 --input $< --output $(subst plans-1,plans-4,$@) --persons src/main/python/table-persons.csv --activities src/main/python/table-activities.csv
	$(sc) prepare activity-sampling --seed 5 --input $< --output $(subst plans-1,plans-5,$@) --persons src/main/python/table-persons.csv --activities src/main/python/table-activities.csv

	$(sc) prepare activity-sampling --seed 1 --input $< --output $@ --persons src/main/python/table-persons.csv --activities src/main/python/table-activities.csv

$p/berlin-initial-$V-25pct.plans.xml.gz: $p/berlin-activities-$V-25pct.plans-1.xml.gz $p/berlin-$V-facilities.xml.gz
	$(sc) prepare init-location-choice\
	 --input "$(subst plans-1,plans-*,$<)"\
	 --output $@\
	 --facilities $(word 2,$^)\
	 --shp $(germany)/vg5000/vg5000_ebenen_0101/VG5000_GEM.shp


# These depend on the output of calibration runs
$p/berlin-uncalibrated-$V-25pct.plans.xml.gz: $p/berlin-$V-facilities.xml.gz $p/berlin-$V-network.xml.gz
	$(sc) prepare filter-relevant-agents\
	 --input output/cadyts_scale_1/*.output_selected_plans.xml.gz --output $@\
	 --shp input/v6.0/area/area.shp\
	 --facilities $<\
	 --network $(word 2,$^)

	$(sc) prepare split-activity-types-duration\
	 --input $@ --output $@

$p/berlin-$V-25pct.plans.xml.gz:
	cp output/route-choice/routeChoice.output_selected_plans.xml.gz $@

	$(sc) prepare downsample-population $@\
     	 --sample-size 0.25\
     	 --samples 0.1 0.01\


prepare-calibration: $p/berlin-initial-$V-25pct.plans.xml.gz
	echo "Done"

prepare: $p/berlin-$V-25pct.plans.xml.gz $p/berlin-$V-network-with-pt.xml.gz
	echo "Done"