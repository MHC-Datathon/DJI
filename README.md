# ACE Insights

## Website URL

https://mhc-datathon.github.io/DJI/

## Intro Video

https://mhc-datathon.github.io/DJI/intro_video.mp4

## Summary

- Interactive SvelteKit site that visualizes MTA Automated Camera Enforcement (ACE) impacts on bus speeds and violation patterns across NYC.
- Map-based storytelling using MapLibre + Deck.gl, with preprocessed datasets produced from `main.ipynb`.
- Focus: CUNY campus corridors, facility correlations (precincts, USPS, health), pre/post ACE speed comparisons, and violation-status spatial analysis.

## Datasets Used

- [MTA Bus Automated Camera Enforced Routes: Beginning October 2019](https://data.ny.gov/Transportation/MTA-Bus-Automated-Camera-Enforced-Routes-Beginning/ki2b-sg5y/about_data)
- [MTA OBA API](https://bustime.mta.info/wiki/Developers/OneBusAwayRESTfulAPI) (via trainstat.us)
- [MTA Bus Speeds: 2015-2019](https://data.ny.gov/Transportation/MTA-Bus-Speeds-2015-2019/cudb-vcni/about_data)
- [MTA Bus Speeds: 2020 - 2024](https://data.ny.gov/Transportation/MTA-Bus-Speeds-2020-2024/6ksi-7cxr/about_data)
- [MTA Bus Speeds: Beginning 2025](https://data.ny.gov/Transportation/MTA-Bus-Speeds-Beginning-2025/4u4b-jge6/about_data)
- [MTA Central Business District Geofence: Beginning June 2024](https://data.ny.gov/Transportation/MTA-Central-Business-District-Geofence-Beginning-J/srxy-5nxn/about_data)
- [City University of New York (CUNY) University Campus Locations](https://data.ny.gov/Education/City-University-of-New-York-CUNY-University-Campus/irqs-74ez/about_data)
- [Health Facility Map](https://health.data.ny.gov/Health/Health-Facility-Map/7dh9-g7ke)
- [Police Precincts](https://www.nyc.gov/site/nypd/bureaus/patrol/precincts-landing.page)
- [USPS Facilities](https://services5.arcgis.com/TBEibzxOE0dzXUyc/arcgis/rest/services/USPS_Facilities_FC_20250221_1/FeatureServer)
- [Borough Boundaries](https://data.cityofnewyork.us/City-Government/Borough-Boundaries/gthc-hcne/about_data)

Fetch USPS facilities:

```bash
curl -G \
  --data-urlencode "where=1=1" \
  --data-urlencode "geometry=-74.25909,40.477399,-73.700272,40.917577" \
  --data-urlencode "geometryType=esriGeometryEnvelope" \
  --data-urlencode "inSR=4326" \
  --data-urlencode "outSR=4326" \
  --data-urlencode "outFields=*" \
  --data-urlencode "f=geojson" \
  "https://services5.arcgis.com/TBEibzxOE0dzXUyc/arcgis/rest/services/USPS_Facilities_FC_20250221_1/FeatureServer/0/query" \
  -o usps_nyc.geojson
```

## Data Setup

1. Run `uv sync` to install dependencies
2. Create a `data/` directory and copy the required datasets to that folder.
3. Open notebook and run all cells.
4. Run `./generate_pmtiles`
