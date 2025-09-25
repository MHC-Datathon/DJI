#!/bin/sh

tippecanoe -o static/data.pmtiles -zg --drop-densest-as-needed --force --generate-ids \
    parsed/cuny_campuses.geojson \
    parsed/bus_routes.geojson \
    parsed/precincts.geojson \
    parsed/usps.geojson \
    parsed/health_facilities.geojson \
    data/cbd.geojson \


# tippecanoe -o frontend/static/violations_by_status.pmtiles -zg --drop-densest-as-needed --force \
#     parsed/violations_by_status.geojson

# tippecanoe -o frontend/static/bus_routes.pmtiles -zg --drop-densest-as-needed --read-parallel --force parsed/bus_routes.geojson

# tippecanoe -o frontend/static/cuny_campuses.pmtiles -zg --drop-densest-as-needed --read-parallel --force parsed/cuny_campuses.geojson