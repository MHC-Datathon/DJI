<script lang="ts">
	import {
		MapLibre,
		VectorTileSource,
		NavigationControl,
		LineLayer,
		CircleLayer,
		Popup,
		FeatureState,
		FillLayer
	} from 'svelte-maplibre-gl';
	import maplibregl from 'maplibre-gl';
	import { PMTilesProtocol } from '@svelte-maplibre-gl/pmtiles';
	import { DeckGLOverlay } from '@svelte-maplibre-gl/deckgl';
	import { HexagonLayer } from '@deck.gl/aggregation-layers';
	import { ArrowLoader } from '@loaders.gl/arrow';
	import { browser } from '$app/environment';
	import { asset } from '$app/paths';
	import type { Attachment } from 'svelte/attachments';
	import { aceRange, congestionPricingStart } from '$lib/constants';
	import SpeedChart from '$lib/SpeedChart.svelte';
	import CustomScrollbar from '$lib/CustomScrollbar.svelte';
	import ViolationStatusPie from '$lib/ViolationStatusPie.svelte';
	import CbdRouteDeltaChart from '$lib/CbdRouteDeltaChart.svelte';
	import PrePostSpeedChart from '$lib/PrePostSpeedChart.svelte';
	// import ChapterIndicator from '$lib/ChapterIndicator.svelte';
	import ace_dates from '$lib/assets/ace_dates.json';
	import campus_list from '$lib/assets/campus_list.json';
	import campus_mapping from '$lib/assets/campus_mapping.json';
	import route_speeds_long from '$lib/assets/route_speeds_long.json';

	// import violation_status_mapping from '$lib/assets/violation_status_mapping.json';
	import violation_status_color_map from '$lib/assets/violations_status_color_map.json';
	import violation_status_manifest from '$lib/assets/violations_status_manifest.json';
	import violation_status_summary from '$lib/assets/violation_status_summary.json';

	const props = $props<{ data: { isFirefox: boolean } }>();

	let isFirefox = $state(props.data.isFirefox);

	if (browser && typeof navigator !== 'undefined') {
		isFirefox = /\bfirefox\b/i.test(navigator.userAgent);
	}

	interface ViolationsByStatus {
		lat: number;
		lng: number;
		violation_status_id: number;
		violation_type_id: number;
	}

	type Layers =
		| 'cuny_campuses'
		| 'bus_routes'
		| 'violations_by_status'
		| 'cbd'
		| 'precincts'
		| 'usps'
		| 'health_facilities';

	type Chapter = {
		id: string;
		title: string;
		text: string;
		center: [number, number];
		zoom: number;
		bearing?: number;
		pitch?: number;
		layers: Partial<{
			[layerId in Layers]: {
				filter?: maplibregl.FilterSpecification;
				paint?: maplibregl.LayerSpecification['paint'];
				popup?: boolean;
				click?: boolean;
				hover?: boolean;
				// only for deckgl layers
				filterRange?: [number, number];
			};
		}>;
		deckLayers?: Partial<{
			[key: string]: {
				// filter?: maplibregl.FilterSpecification;
				// paint?: maplibregl.LayerSpecification['paint'];
				// popup?: boolean;
				// click?: boolean;
				// hover?: boolean;
				// // only for deckgl layers
				// filterRange?: [number, number];
			};
		}>;
		duration: number;
		interactive: boolean;
		// not used
		scrollZoom?: boolean;
	};

	const colorRangeViolationStatus = Object.values(violation_status_color_map);

	// const colorRangeViolationStatus = violation_status_mapping
	// 	// .sort((a, b) => a.violation_status_id - b.violation_status_id)
	// 	.map((item) => item.violation_status_rgb) as [number, number, number][];

	// const issued_status_id = violation_status_mapping.find(
	// 	(v) => v.violation_status.toLowerCase() === 'violation issued'
	// )!.violation_status_id;

	// build a Mapbox/MapLibre filter that is true when any campus boolean column is true
	const campusAnyFilter = (() => {
		// campus_mapping items look like { original, sanitized }
		const clauses = (campus_mapping as Array<{ original: string; sanitized: string }>).map((c) => [
			'==',
			['get', c.sanitized],
			true
		]);
		if (clauses.length === 0) return ['!=', ['get', 'campus'], null]; // fallback to original behavior
		return ['any', ...clauses];
	})();

	// Layer toggles for facilities chapter
	let facilityLayerToggles = $state({
		precincts: true,
		usps: true,
		health_facilities: true
	});

	// Derived paint properties for facility layers based on toggles
	const facilityLayerPaint = $derived.by(() => ({
		health_facilities: {
			'circle-radius': 6,
			'circle-color': '#B10DC9',
			'circle-stroke-width': 2,
			'circle-stroke-color': '#FFFFFF',
			'circle-opacity': facilityLayerToggles.health_facilities ? 0.9 : 0,
			'circle-stroke-opacity': facilityLayerToggles.health_facilities ? 1 : 0
		},
		precincts: {
			'circle-radius': 6,
			'circle-color': '#3F51B5',
			'circle-stroke-width': 2,
			'circle-stroke-color': '#FFFFFF',
			'circle-opacity': facilityLayerToggles.precincts ? 0.9 : 0,
			'circle-stroke-opacity': facilityLayerToggles.precincts ? 1 : 0
		},
		usps: {
			'circle-radius': 6,
			'circle-color': '#4CAF50',
			'circle-stroke-width': 2,
			'circle-stroke-color': '#FFFFFF',
			'circle-opacity': facilityLayerToggles.usps ? 0.9 : 0,
			'circle-stroke-opacity': facilityLayerToggles.usps ? 1 : 0
		}
	}));

	// Helper function to get paint properties for facility layers
	const getFacilityLayerPaint = (layerId: keyof typeof facilityLayerPaint) => {
		if (activeChapter.id === 'facility-layers') {
			return facilityLayerPaint[layerId];
		}
		// For other chapters that might have facility layers, return default paint
		return {
			'circle-radius': 6,
			'circle-color':
				layerId === 'health_facilities'
					? '#B10DC9'
					: layerId === 'precincts'
						? '#3F51B5'
						: '#4CAF50',
			'circle-stroke-width': 2,
			'circle-stroke-color': '#FFFFFF',
			'circle-opacity': 0.9,
			'circle-stroke-opacity': 1
		};
	};

	// Story chapters configuration
	const storyChapters: Chapter[] = [
		{
			id: 'intro',
			title: 'MTA ACE Program: Making Buses Faster',
			// text: "The MTA's Automated Camera Enforcement (ACE) program uses bus-mounted cameras to catch vehicles blocking bus lanes and stops. Since October 2019, it has been deployed on 39 routes serving 775K daily riders.",
			text: 'Automated camera enforcement programs use vehicle-mounted cameras to detect and deter illegal stopping and blocking of bus lanes and stops. Deployed in recent years across many routes, these programs aim to improve bus speed, reliability, and safety for riders. This story explores how enforcement, infrastructure, and service changes intersect with travel times and community outcomes across different neighborhoods and routes.',
			center: [-74.006, 40.7128] as [number, number],
			zoom: 12,
			layers: {
				bus_routes: {
					// filter: ['all'],
					paint: {
						'line-opacity': 0.7,
						'line-width': 3,
						'line-color': '#888888'
					}
				},
				cuny_campuses: {
					paint: {
						'circle-radius': 6,
						'circle-color': '#FF5722',
						'circle-stroke-width': 2,
						'circle-stroke-color': '#FFFFFF',
						'circle-opacity': 0.9
					}
				}
			},
			duration: 1200,
			interactive: false
		},
		{
			id: 'cuny-routes',
			title: 'CUNY Student Transit Corridors',
			text: "CUNY's 26 campuses serve over 240,000 students across all five boroughs. Many rely on buses for their daily commute. Let's explore which routes students depend on most and how camera enforcement has changed their travel experience. On the map, orange dots mark CUNY campuses, while colored lines indicate bus routes with stops within 500 feet of a campus.",
			center: [-73.935242, 40.73061] as [number, number],
			zoom: 11,
			layers: {
				bus_routes: {
					paint: {
						// 'line-opacity': ,
						'line-width': 3,
						'line-color': ['get', 'color']
					},
					// filter for where any campus boolean column is true
					filter: campusAnyFilter
				},
				cuny_campuses: {
					paint: {
						'circle-radius': 6,
						'circle-color': '#FF5722',
						'circle-stroke-width': 2,
						'circle-stroke-color': '#FFFFFF',
						'circle-opacity': 0.9
					}
				}
			},
			duration: 1500,
			interactive: false
		},
		{
			id: 'cuny-ace-implementation',
			title: 'ACE on CUNY Bus Routes',
			text: "ACE wasn't implemented everywhere at once. The program started in October 2019 and gradually expanded. You can filter for specific campuses or hover over routes to see when ACE began there. Gray routes haven't had ACE implemented yet.",
			center: [-73.935242, 40.73061] as [number, number],
			zoom: 11,
			layers: {
				bus_routes: {
					paint: {
						'line-width': [
							'case',
							['boolean', ['feature-state', 'hover'], false],
							5, // Width when hovered
							3 // Default width
						],
						// color: implementation_date -> color, otherwise gray
						'line-color': [
							'case',
							['!=', ['get', 'implementation_date'], null],
							['get', 'color'],
							'#888888'
						]
						// dim non-ACE routes by lowering opacity when implementation_date is null
						// 'line-opacity': ['case', ['!=', ['get', 'implementation_date'], null], 0.95, 0.45]
					},
					// only consider routes that are nearby a campus
					filter: campusAnyFilter,
					popup: true,
					hover: true
				},
				cuny_campuses: {
					paint: {
						'circle-radius': 6,
						'circle-color': '#FF5722',
						'circle-stroke-width': 2,
						'circle-stroke-color': '#FFFFFF',
						'circle-opacity': 0.9
					}
				}
			},
			duration: 1500,
			interactive: true
		},
		{
			id: 'pre-post-ace-speeds',
			title: 'ACE Speed Impact Overview',
			text: "Before diving into specific routes, let's examine the overall impact of ACE implementation. This chart shows the top routes by speed improvement, comparing average speeds before and after ACE enforcement began. Most routes show meaningful speed increases, validating the effectiveness of camera enforcement.",
			center: [-73.935242, 40.73061] as [number, number],
			zoom: 11,
			layers: {
				bus_routes: {
					paint: {
						'line-width': [
							'case',
							['boolean', ['feature-state', 'hover'], false],
							5, // Width when hovered
							3 // Default width
						],
						'line-color': [
							'case',
							['!=', ['get', 'implementation_date'], null],
							['get', 'color'], // Color if implementation date exists
							'#888888' // Gray if no ACE implementation
						]
					},
					filter: ['!=', ['get', 'implementation_date'], null],
					hover: true
				},
				cuny_campuses: {
					paint: {
						'circle-radius': 6,
						'circle-color': '#FF5722',
						'circle-stroke-width': 2,
						'circle-stroke-color': '#FFFFFF',
						'circle-opacity': 0.9
					}
				}
			},
			duration: 1500,
			interactive: true
		},
		{
			id: 'cuny-ace-affects',
			title: "ACE's affect on CUNY Bus Routes",
			text: "How has ACE affected bus routes serving CUNY campuses? Let's explore speed trends over time.",
			center: [-73.935242, 40.73061] as [number, number],
			zoom: 11,
			layers: {
				bus_routes: {
					paint: {
						'line-width': [
							'case',
							['boolean', ['feature-state', 'hover'], false],
							5, // Width when hovered
							3 // Default width
						],
						'line-color': [
							'case',
							['!=', ['get', 'implementation_date'], null],
							['get', 'color'], // Color if implementation date exists
							'gray' // Color if implementation date does not exist
						]
					},
					filter: ['!=', ['get', 'implementation_date'], null],
					click: true,
					hover: true
				},
				cuny_campuses: {
					paint: {
						'circle-radius': 6,
						'circle-color': '#FF5722',
						'circle-stroke-width': 2,
						'circle-stroke-color': '#FFFFFF',
						'circle-opacity': 0.9
					}
				}
			},
			duration: 1500,
			interactive: true
		},
		{
			id: 'violations-by-status',
			title: 'Violations by Status',
			text: 'Lets look at the distribution of violations by status across different areas. This view helps understand where enforcement is most active and how it varies by violation type.',
			center: [-73.98285203796434, 40.79736277667925],
			zoom: 11.768114477849783,
			bearing: 0,
			pitch: 60,
			layers: {
				bus_routes: {
					paint: {
						'line-width': 10,
						'line-color': ['get', 'color']
					},
					filter: ['!=', ['get', 'implementation_date'], null]
				}
			},
			duration: 1500,
			interactive: true,
			scrollZoom: false
		},
		{
			id: 'facility-layers',
			title: 'Urban Infrastructure & Violation Patterns',
			text: 'Different types of urban facilities may correlate with ACE violation patterns. Toggle the layers below to explore how police precincts (blue), USPS facilities (green), and health facilities (purple) relate to violation hotspots. Notice patterns near these institutional locations. In the next chapters, we will explore some specific examples.',
			center: [-73.98285203796434, 40.79736277667925],
			zoom: 11.768114477849783,
			bearing: 0,
			pitch: 60,
			layers: {
				bus_routes: {
					paint: {
						'line-width': 10,
						'line-color': ['get', 'color']
					},
					filter: ['!=', ['get', 'implementation_date'], null]
				},
				health_facilities: {
					// paint properties will be computed reactively via getFacilityLayerPaint
				},
				precincts: {
					// paint properties will be computed reactively via getFacilityLayerPaint
				},
				usps: {
					// paint properties will be computed reactively via getFacilityLayerPaint
				}
			},
			duration: 1500,
			interactive: true,
			scrollZoom: false
		},
		{
			id: 'violation-exemptions-bus',
			title: 'Bus / Paratransit Exemptions',
			text: `Buses and paratransit vehicles are exempt from ACE violations. There are ${
				violation_status_summary.find((d) => d['Violation Status'] === 'EXEMPT - BUS/PARATRANSIT')
					?.count ?? 'N/A'
			} recorded exemptions in our dataset. One of the largest clusters of exemptions appears near Utica Ave and Eastern Parkway. From our experience using the train station nearby, this area often has dollar vans illegally parked.`,
			center: [-73.93186130516904, 40.67864793102734],
			zoom: 14,
			bearing: 30.639995950211638,
			pitch: 60,
			layers: {
				bus_routes: {
					paint: {
						// 'line-opacity': ,
						'line-width': 10,
						'line-color': ['get', 'color']
					},
					filter: ['!=', ['get', 'implementation_date'], null]
				}
			},
			duration: 2500,
			interactive: true,
			// TODO: fix fly getting cancelled bc user accidentally scrolls
			scrollZoom: false,
			deckLayers: {
				'EXEMPT - BUS/PARATRANSIT': {}
			}
		},
		{
			id: 'violation-exemptions-emergency',
			title: 'Emergency Vehicle Exemptions',
			text: `Emergency vehicles - ambulances, fire trucks, and police - are exempt from ACE violations when responding to calls. Our records show ${
				violation_status_summary.find((d) => d['Violation Status'] === 'EXEMPT - EMERGENCY VEHICLE')
					?.count ?? 'N/A'
			} such exemptions. However, some exemptions may not always be warranted. Notice how police precincts (blue dots) often correlate with clusters of emergency vehicle exemptions, suggesting potential misuse of emergency status for routine operations.`,
			center: [-73.92056473062263, 40.80720148797684],
			zoom: 14,
			bearing: -113.0489704146031,
			pitch: 60,
			layers: {
				bus_routes: {
					paint: {
						'line-width': 5,
						'line-color': ['get', 'color']
					},
					filter: ['!=', ['get', 'implementation_date'], null]
				},
				cuny_campuses: {
					paint: {
						'circle-radius': 6,
						'circle-color': '#FF5722',
						'circle-stroke-width': 2,
						'circle-stroke-color': '#FFFFFF',
						'circle-opacity': 0.9
					}
				},
				precincts: {
					paint: {
						'circle-radius': 10,
						'circle-color': '#3F51B5',
						'circle-stroke-width': 2,
						'circle-stroke-color': '#FFFFFF'
						// 'circle-opacity': 1
					}
				}
			},
			duration: 2500,
			interactive: true,
			scrollZoom: false,
			deckLayers: {
				'EXEMPT - EMERGENCY VEHICLE': {}
			}
		},
		{
			id: 'violation-driver-info-missing',
			title: 'Technical Issues: Missing Driver Info',
			text: `A significant portion of violations cannot be processed due to missing driver or vehicle information. Our dataset contains ${
				violation_status_summary.find(
					(d) => d['Violation Status'] === 'DRIVER/VEHICLE INFO MISSING'
				)?.count ?? 'N/A'
			} such records. One of the possible causes is cars packed closely together, making it hard to capture clear images of license plates and driver details.`,
			center: [-73.97412439606387, 40.73453739755777],
			zoom: 12.000000000000002,
			bearing: 0,
			pitch: 60,
			layers: {
				bus_routes: {
					paint: {
						'line-width': 4,
						'line-color': ['get', 'color']
					},
					filter: ['!=', ['get', 'implementation_date'], null]
				},
				cuny_campuses: {
					paint: {
						'circle-radius': 4,
						'circle-color': '#FF5722',
						'circle-stroke-width': 1,
						'circle-stroke-color': '#FFFFFF',
						'circle-opacity': 0.7
					}
				}
			},
			duration: 2000,
			interactive: true,
			scrollZoom: false,
			deckLayers: {
				'DRIVER/VEHICLE INFO MISSING': {}
			}
		},
		{
			id: 'cbd-violations',
			title: "Congestion Pricing's Impact on ACE Violations",
			text: 'Congestion pricing decreased ACE violations for a majority of bus routes in the CBD area, especially the M15+ and M14A+. However, other factors could be contributing to these changes, such as bus network redesigns.',
			center: [-74.00261952816732, 40.73672409118353],
			zoom: 12,
			bearing: 21.41987532427561,
			pitch: 0,
			layers: {
				bus_routes: {
					paint: {
						'line-width': 4,
						'line-color': ['get', 'color']
					},
					filter: [
						'all',
						// check that implementation date is greater than cp start
						['>=', ['get', 'implementation_date'], congestionPricingStart.getTime() / 1000],
						// ['!=', ['get', 'implementation_date'], null],
						['==', ['get', 'in_cbd'], true]
					],
					hover: true,
					popup: true
				},
				cbd: {}
				// cuny_campuses: {
				// 	paint: {
				// 		'circle-radius': 4,
				// 		'circle-color': '#FF5722',
				// 		'circle-stroke-width': 1,
				// 		'circle-stroke-color': '#FFFFFF',
				// 		'circle-opacity': 0.7
				// 	}
				// }
			},
			duration: 1500,
			interactive: true,
			scrollZoom: false
		},
		{
			id: 'conclusion',
			title: 'Conclusion',
			text: 'This exploration showed how automated enforcement, local infrastructure, and service changes relate to bus performance and observed violation patterns across the city. Key takeaways: enforcement can improve reliability on many routes, spatial patterns around facilities are informative, and data limitations (missing driver info, inconsistent records) matter. Patterns near police precincts, postal facilities, and health sites can point to targeted street-design interventions — for example, improved curb management and loading zones, adjusted signal timing, clearer bus stop placement, and pedestrian safety measures.',
			center: [-73.98, 40.73],
			zoom: 11,
			layers: {
				bus_routes: {
					paint: {
						'line-width': 2,
						'line-color': ['get', 'color']
					}
				}
			},
			duration: 2000,
			interactive: false
		}
	] as const;

	let cursor: 'default' | 'pointer' | undefined = $state();
	let map = $state<maplibregl.Map>();

	let activeChapter = $state(storyChapters[0]);
	let activeChapterIndex = $derived(
		storyChapters.findIndex((chapter) => chapter.id === activeChapter.id)
	);
	let scrollProgress = $state(0); // 0-100 percentage
	let chapterProgress = $state(0); // 0-100 percentage within current chapter

	const campusLookup = new Map(campus_mapping.map((c) => [c.original, c.sanitized]));

	// reverse lookup: sanitized -> original for displaying names from boolean columns
	const campusReverseLookup = new Map(campus_mapping.map((c) => [c.sanitized, c.original]));

	// reactive derived list of campus names for the currently hovered route feature
	const hoveredCampusList = $derived.by(() => {
		if (!hoveredRouteFeature?.properties) return [];
		const props = hoveredRouteFeature.properties as Record<string, any>;
		const result: string[] = [];
		for (const [sanitized, original] of campusReverseLookup.entries()) {
			if (props[sanitized] === true || props[sanitized] === 'true') {
				result.push(original);
			}
		}
		// fallback to old `campus` property if present and no booleans found
		if (result.length === 0 && typeof props['campus'] === 'string' && props['campus'] !== '') {
			result.push(props['campus']);
		}
		return result;
	});

	// filters
	let selectedCampus = $state('All');
	let scrollZoomEnabled = $state(false);
	let dateRange = $state([...aceRange]);

	const currentCampusFilter: maplibregl.FilterSpecification | undefined = $derived.by(() => {
		if (activeChapter.id !== 'cuny-ace-implementation') {
			return undefined;
		}
		if (selectedCampus === 'All') {
			return undefined;
		}

		// Use the sanitized column name for filtering
		const sanitizedCampus = campusLookup.get(selectedCampus);
		if (!sanitizedCampus) return undefined;

		return ['==', ['get', sanitizedCampus], true];
	});

	const currentDateFilter: maplibregl.FilterSpecification | undefined = $derived.by(() => {
		if (activeChapter.id !== 'cuny-ace-implementation') {
			return undefined;
		}

		return [
			'all',
			['!=', ['get', 'implementation_date'], null],
			['>=', ['get', 'implementation_date'], dateRange[0].getTime() / 1000],
			['<=', ['get', 'implementation_date'], dateRange[1].getTime() / 1000]
		];
	});

	const routeFilter: maplibregl.FilterSpecification | undefined = $derived.by(() => {
		const baseFilter = activeChapter.layers?.bus_routes?.filter;
		const campusFilter = currentCampusFilter;
		const dateFilter = currentDateFilter;

		// Collect all non-undefined filters
		const filters = [baseFilter, campusFilter, dateFilter].filter(
			(filter): filter is maplibregl.FilterSpecification => filter !== undefined
		);

		if (filters.length === 0) {
			return undefined;
		}
		if (filters.length === 1) {
			return filters[0];
		}

		return ['all', ...filters];
	});

	const visibleDeckLayers = $derived.by(() => {
		if (activeChapter.id === 'violations-by-status') {
			// TODO: show layers that are selected in pie chart
		}

		if (!activeChapter.deckLayers) return {};
		const result: Record<string, boolean> = {};
		for (const key of Object.keys(activeChapter.deckLayers)) {
			result[key] = true;
		}
		return result;
	});

	let hoveredRouteFeature: maplibregl.MapGeoJSONFeature | undefined = $state.raw();
	let routeLnglat = $state.raw(new maplibregl.LngLat(0, 0));
	// let clickedRouteId = $state<string | undefined>();

	let clickedRouteFeature: maplibregl.MapGeoJSONFeature | undefined = $state.raw();

	// Build lookup maps for chart data and ACE timestamps
	const speedsByRoute = $derived.by(() => {
		const m = new Map<string, Array<{ ts: number; speed: number; speed_3m?: number }>>();
		for (const row of route_speeds_long as Array<{
			route_id: string;
			ts: number;
			speed: number;
			speed_3m?: number | null;
		}>) {
			const arr = m.get(row.route_id) ?? [];
			arr.push({ ts: row.ts, speed: row.speed, speed_3m: row.speed_3m ?? undefined });
			m.set(row.route_id, arr);
		}
		// ensure time order
		for (const arr of m.values()) arr.sort((a, b) => a.ts - b.ts);
		return m;
	});

	const aceTsByRoute = $derived.by(() => {
		const m = new Map<string, number>();
		for (const row of ace_dates as Array<{ route_id: string; ts: number }>) {
			if (row.ts) m.set(row.route_id, row.ts);
		}
		return m;
	});

	// Chapter data for components
	const chapterTitles = $derived(storyChapters.map((chapter) => chapter.title));
	const totalChapters = $derived(storyChapters.length);

	// Story scroll tracking with attachments
	const storyScrollTracker: Attachment = (element) => {
		const observer = new IntersectionObserver(
			(entries) => {
				entries.forEach((entry) => {
					if (entry.isIntersecting && entry.intersectionRatio > 0.6) {
						const sections = element.querySelectorAll('.story-section') as NodeListOf<HTMLElement>;
						const index = Array.from(sections).indexOf(entry.target as HTMLElement);

						if (index !== -1 && storyChapters[index].id !== activeChapter.id) {
							activeChapter = storyChapters[index];
							// updateMapForChapter(storyChapters[index]);
						}
					}

					// Calculate chapter progress based on intersection ratio for the active chapter
					if (entry.isIntersecting) {
						const sections = element.querySelectorAll('.story-section') as NodeListOf<HTMLElement>;
						const index = Array.from(sections).indexOf(entry.target as HTMLElement);

						if (index !== -1 && storyChapters[index].id === activeChapter.id) {
							chapterProgress = Math.round(entry.intersectionRatio * 100);
						}
					}
				});
			},
			{
				threshold: Array.from({ length: 21 }, (_, i) => i * 0.05), // 0, 0.05, 0.1, ... 1.0
				rootMargin: '-20% 0px -20% 0px' // More restrictive margins
			}
		);

		// Track overall scroll progress
		const updateScrollProgress = () => {
			const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
			const scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
			scrollProgress = Math.round((scrollTop / scrollHeight) * 100);
		};

		window.addEventListener('scroll', updateScrollProgress);
		updateScrollProgress(); // Initial calculation

		// Observe all story sections
		const sections = element.querySelectorAll('.story-section');
		sections.forEach((section) => observer.observe(section));

		// Cleanup function
		return () => {
			sections.forEach((section) => observer.unobserve(section));
			observer.disconnect();
			window.removeEventListener('scroll', updateScrollProgress);
		};
	};

	$inspect(activeChapter);
	$inspect(routeFilter);

	$effect(() => {
		if (activeChapter) {
			updateMapForChapter(activeChapter);
			// console.log('chapter changed', activeChapter);
			// updateMapForChapter(activeChapter);
		}
	});

	function updateMapForChapter(chapter: (typeof storyChapters)[0]) {
		if (!map) return;

		map.flyTo({
			center: chapter.center,
			zoom: chapter.zoom,
			duration: chapter.duration,
			bearing: chapter.bearing ?? 0,
			pitch: chapter.pitch ?? 0
		});

		// Update layer visibility logic would go here
		// updateLayerVisibility(chapter.layers);
	}
	// $inspect(cursor);
</script>

<PMTilesProtocol />

<div class="custom-scrollbar relative bg-slate-900">
	<div class="fixed inset-0 z-0">
		<!-- "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json" -->
		<MapLibre
			bind:map
			attributionControl={false}
			style="https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json"
			center={[-74.006, 40.7128]}
			maxBounds={[
				[-74.45909, 40.277399],
				[-73.000272, 41.017577]
			]}
			zoom={11}
			maxZoom={17}
			scrollZoom={scrollZoomEnabled}
			{cursor}
			class="h-[100dvh] w-[100dvw]"
		>
			<!-- onmoveend={({ target: map }) => {
				// Get the current map position information
				const center = map.getCenter();
				const zoom = map.getZoom();
				const bearing = map.getBearing();
				const pitch = map.getPitch();

				// console.dir({
				// 	center: [center.lng, center.lat],
				// 	zoom,
				// 	bearing,
				// 	pitch
				// });
			}} -->
			<NavigationControl position="bottom-left" />

			{#if !isFirefox}
				<DeckGLOverlay
					interleaved
					getTooltip={({ object }) => {
						if (!object) return null;
						// console.log(object);
						// return null;
						return {
							text: `Count: ${object.count}`
						};
					}}
					layers={[
						new HexagonLayer<ViolationsByStatus>({
							// visible: activeChapter.deckLayers?.[violation_type.status] !== undefined,
							visible: ['facility-layers', 'violations-by-status'].includes(activeChapter.id),
							id: `violation-all`,
							data: asset('/violations_by_status.arrow'),
							gpuAggregation: true,
							extruded: true,
							pickable: true,
							elevationScale: 5,
							// cellSize: 75,
							opacity: 0.6,
							radius: 75,
							loaders: [ArrowLoader],
							loadOptions: {
								arrow: {
									shape: 'object-row-table'
								}
							},
							getPosition: (d) => [d.lng, d.lat],
							// getElevationWeight: (d) => 1,
							// elevationAggregation: 'COUNT',
							getColorWeight: (d) => d.violation_status_id,
							colorScaleType: 'ordinal',
							colorRange: colorRangeViolationStatus

							// colorScaleType: 'quantize',
							// colorDomain: [
							// 	violation_status_mapping[0].violation_status_id,
							// 	violation_status_mapping[violation_status_mapping.length - 1].violation_status_id
							// ],
							// colorRange: [violation_type.color as [number, number, number]]
						}),
						...violation_status_manifest.map(
							(violation_type) =>
								new HexagonLayer<ViolationsByStatus>({
									// visible: activeChapter.deckLayers?.[violation_type.status] !== undefined,
									visible: visibleDeckLayers[violation_type.status] === true,
									id: `violation-${violation_type.status}`,
									data: asset('/' + violation_type.file),
									gpuAggregation: true,
									extruded: true,
									pickable: false,
									elevationScale: 5,
									// cellSize: 75,
									radius: 75,
									loaders: [ArrowLoader],
									loadOptions: {
										arrow: {
											shape: 'object-row-table'
										}
									},
									getPosition: (d) => [d.lng, d.lat],
									// getElevationWeight: (d) => 1,
									// elevationAggregation: 'COUNT',
									getColorWeight: (d) => d.violation_status_id,
									colorScaleType: 'ordinal',
									// colorScaleType: 'quantize',
									// colorDomain: [
									// 	violation_status_mapping[0].violation_status_id,
									// 	violation_status_mapping[violation_status_mapping.length - 1].violation_status_id
									// ],
									colorRange: [violation_type.color as [number, number, number]]
									// onFilteredItemsChange: (filteredItems) => {
									// 	console.log('Filtered items count:', filteredItems.count);
									// },
									// extensions: [new DataFilterExtension({ filterSize: 1, countItems: true })],
									// getFilterValue: (d) => d.violation_status_id,
									// filterRange: undefined
								})
						)
					]}
				/>
			{/if}

			<VectorTileSource url={`pmtiles://${asset('/data.pmtiles')}`}>
				{#each Object.entries(activeChapter.layers) as [layerId, layer]}
					{#if layerId === 'bus_routes'}
						<LineLayer
							sourceLayer={layerId}
							layout={{ 'line-cap': 'round', 'line-join': 'round' }}
							paint={layer.paint}
							filter={routeFilter}
						/>
						<!-- TODO: fix cursor not working -->
						<!-- hover buffer -->
						<LineLayer
							sourceLayer={layerId}
							layout={{ 'line-cap': 'round', 'line-join': 'round' }}
							paint={{
								'line-width': 10,
								'line-opacity': 0
							}}
							filter={routeFilter}
							onmousemove={(ev) => {
								cursor = 'pointer';
								hoveredRouteFeature = ev.features?.[0];
								routeLnglat = ev.lngLat;
							}}
							onmouseleave={() => {
								cursor = 'default';
								hoveredRouteFeature = undefined;
							}}
							onclick={(ev) => {
								clickedRouteFeature = ev.features?.[0];
								// // store clicked route for chart
								// const feat = ev.features?.[0];
								// if (feat?.properties?.id) clickedRouteId = feat.properties.id;
							}}
						/>

						{#if layer.hover && hoveredRouteFeature}
							<FeatureState
								sourceLayer={layerId}
								id={hoveredRouteFeature.id}
								state={{ hover: true }}
							/>
						{/if}

						{#if layer.click && clickedRouteFeature}
							<FeatureState
								sourceLayer={layerId}
								id={clickedRouteFeature.id}
								state={{ click: true }}
							/>
						{/if}

						{#if hoveredRouteFeature && layer.popup}
							<Popup lnglat={routeLnglat} closeButton={false}>
								<h3 class="mb-1 text-lg font-bold text-slate-900">
									Route: {hoveredRouteFeature.properties?.id}
								</h3>
								{#if hoveredRouteFeature.properties?.['implementation_date']}
									<p class="text-sm text-slate-700">
										<strong>Implementation Date:</strong>
										{new Date(
											hoveredRouteFeature.properties?.['implementation_date'] * 1000
										).toLocaleDateString()}
									</p>
								{:else}
									<p class="text-sm text-slate-700">No ACE Implementation</p>
								{/if}
								{#if hoveredCampusList.length > 0}
									<p class="text-sm text-slate-700">
										<strong>Campus Nearby:</strong>
										{hoveredCampusList.join(', ')}
									</p>
								{/if}
								<p class="mt-2 text-xs text-slate-500">Click the route to lock the chart.</p>
							</Popup>
						{/if}
					{:else if layerId === 'cuny_campuses'}
						<CircleLayer sourceLayer={layerId} paint={layer.paint} />
					{:else if layerId === 'precincts'}
						<CircleLayer sourceLayer={layerId} paint={getFacilityLayerPaint('precincts')} />
					{:else if layerId === 'usps'}
						<CircleLayer sourceLayer={layerId} paint={getFacilityLayerPaint('usps')} />
					{:else if layerId === 'health_facilities'}
						<CircleLayer sourceLayer={layerId} paint={getFacilityLayerPaint('health_facilities')} />
					{:else if layerId === 'cbd'}
						<FillLayer
							sourceLayer={layerId}
							paint={{
								'fill-color': '#00ff55',
								'fill-opacity': 0.3
							}}
						/>
					{/if}
				{/each}
			</VectorTileSource>
		</MapLibre>
	</div>

	{#if isFirefox}
		<div class="pointer-events-none fixed inset-x-0 top-6 z-20 flex justify-center px-4">
			<div
				class="pointer-events-auto max-w-xl rounded-lg border border-amber-300 bg-amber-100/95 px-4 py-3 text-sm font-medium text-amber-900 shadow-xl"
			>
				<span class="font-semibold">Firefox notice:</span>
				<span class="ml-1">
					This browser disables our GPU-accelerated hexagon layers. Please try Chrome, Edge, or
					Safari for the full interactive map experience.
				</span>
			</div>
		</div>
	{/if}

	<!-- Custom Scrollbar -->
	<CustomScrollbar
		{scrollProgress}
		{chapterProgress}
		{activeChapterIndex}
		{totalChapters}
		{chapterTitles}
	/>

	<!-- Chapter Progress Indicator -->
	<!-- <ChapterIndicator 
		{activeChapterIndex}
		activeChapterTitle={activeChapter.title}
		{totalChapters}
		{chapterTitles}
		{chapterProgress}
	/> -->

	<!-- Scrollable story content -->
	<div class="pointer-events-none relative z-10" {@attach storyScrollTracker}>
		{#each storyChapters as chapter, i}
			<section class="story-section flex min-h-screen items-center justify-start">
				<div
					class="pointer-events-auto mx-8 max-w-lg rounded-xl bg-white/95 p-8 shadow-2xl backdrop-blur-md"
				>
					<input
						type="checkbox"
						aria-label="Enable map scroll zoom"
						bind:checked={scrollZoomEnabled}
					/>
					<span>Zoom on scroll</span>
					<h2 class="mb-4 text-3xl font-bold text-slate-900">{chapter.title}</h2>

					{#if chapter.id === 'intro'}
						<a
							href={asset('/intro_video.mp4')}
							target="_blank"
							class="mb-4 inline-block rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
							>Watch Intro Video</a
						>
					{/if}

					<p class="mb-6 text-lg leading-relaxed text-slate-700">{chapter.text}</p>

					<!-- Interactive controls for ACE timeline chapter -->
					{#if chapter.interactive && chapter.id === 'cuny-ace-implementation'}
						<div class="rounded-lg bg-slate-200 p-4">
							<h3 class="mb-2 font-semibold text-slate-800">Campus Filter</h3>
							<select
								bind:value={selectedCampus}
								class="mb-4 w-full rounded border border-slate-300 bg-white px-3 py-2 shadow-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-none"
							>
								<option value="All">All ACE Routes</option>
								{#each campus_list as campus}
									<option value={campus}>{campus}</option>
								{/each}
							</select>
							<!-- date slider -->
							<div class="mb-4">
								<label class="mb-2 block text-sm font-medium text-slate-700">Date Range:</label>
								<div class="space-y-2">
									<div>
										<label class="text-xs text-slate-600">From:</label>
										<input
											type="range"
											min={aceRange[0].getTime()}
											max={aceRange[1].getTime()}
											step={86400000}
											value={dateRange[0].getTime()}
											oninput={(e) => {
												// @ts-ignore
												dateRange = [new Date(parseInt(e.target.value)), dateRange[1]];
											}}
											class="w-full"
										/>
									</div>
									<div>
										<label class="text-xs text-slate-600">To:</label>
										<input
											type="range"
											min={aceRange[0].getTime()}
											max={aceRange[1].getTime()}
											step={86400000}
											value={dateRange[1].getTime()}
											oninput={(e) => {
												// @ts-ignore
												dateRange = [dateRange[0], new Date(parseInt(e.target.value))];
											}}
											class="w-full"
										/>
									</div>
								</div>
								<div class="mt-2 text-sm text-slate-600">
									From: {dateRange[0].toLocaleDateString()} - To: {dateRange[1].toLocaleDateString()}
								</div>
							</div>
						</div>
					{/if}

					<!-- Interactive controls for facility layers chapter -->
					{#if chapter.interactive && chapter.id === 'facility-layers'}
						<div class="rounded-lg bg-slate-200 p-4">
							<h3 class="mb-2 font-semibold text-slate-800">Facility Layers</h3>
							<div class="space-y-2">
								<label class="flex items-center space-x-3">
									<input
										type="checkbox"
										bind:checked={facilityLayerToggles.precincts}
										class="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
									/>
									<div class="flex items-center space-x-2">
										<div class="h-3 w-3 rounded-full border border-white bg-blue-600"></div>
										<span class="text-sm text-slate-700">Police Precincts</span>
									</div>
								</label>

								<label class="flex items-center space-x-3">
									<input
										type="checkbox"
										bind:checked={facilityLayerToggles.usps}
										class="h-4 w-4 rounded border-gray-300 text-green-600 focus:ring-green-500"
									/>
									<div class="flex items-center space-x-2">
										<div class="h-3 w-3 rounded-full border border-white bg-green-600"></div>
										<span class="text-sm text-slate-700">USPS Facilities</span>
									</div>
								</label>

								<label class="flex items-center space-x-3">
									<input
										type="checkbox"
										bind:checked={facilityLayerToggles.health_facilities}
										class="h-4 w-4 rounded border-gray-300 text-purple-600 focus:ring-purple-500"
									/>
									<div class="flex items-center space-x-2">
										<div class="h-3 w-3 rounded-full border border-white bg-purple-600"></div>
										<span class="text-sm text-slate-700">Health Facilities</span>
									</div>
								</label>
							</div>
						</div>
					{/if}

					<!-- Charts for specific chapters -->
					{#if chapter.id === 'pre-post-ace-speeds'}
						<div class="rounded-lg bg-slate-50 p-4">
							<h3 class="mb-2 font-semibold text-slate-800">Speed Impact Analysis</h3>
							<p class="mb-3 text-sm text-slate-600">
								Comparing average speeds before and after ACE implementation for top-performing
								routes.
							</p>
							<PrePostSpeedChart maxRoutes={15} sortBy="delta_mph" ascending={false} />
						</div>
					{:else if chapter.id === 'cuny-ace-affects'}
						<div class="rounded-lg bg-slate-50 p-4">
							<h3 class="mb-2 font-semibold text-slate-800">Speed over time</h3>
							<p class="mb-3 text-sm text-slate-600">
								Click a route on the map to update the chart. You can also zoom into the chart with
								your mouse wheel or trackpad.
							</p>
							<SpeedChart
								routeId={clickedRouteFeature?.properties?.id}
								dataByRoute={speedsByRoute}
								{aceTsByRoute}
								height={220}
							/>
						</div>
					{:else if chapter.id === 'violations-overview'}
						<div class="rounded-lg bg-slate-50 p-4">
							<h3 class="mb-2 font-semibold text-slate-800">Violation Statistics</h3>
							<p class="text-sm text-slate-600">Chart visualization coming soon...</p>
						</div>
					{:else if chapter.id === 'violations-by-status'}
						<div class="rounded-lg bg-slate-50 p-4">
							<h3 class="mb-2 font-semibold text-slate-800">Violations by Status</h3>
							<p class="mb-2 text-sm text-slate-600">
								Distribution of violation outcomes across the dataset.
							</p>
							<p class="mb-3 text-xs text-slate-500">
								Note: Chart colors don't match the map colors
							</p>
							<ViolationStatusPie />
						</div>
					{:else if chapter.id === 'cbd-violations'}
						<div class="rounded-lg bg-slate-50 p-4">
							<h3 class="mb-2 font-semibold text-slate-800">
								CBD Violations — route change (post − pre)
							</h3>
							<p class="mb-3 text-sm text-slate-600">
								Top routes in the CBD by absolute change in ACE violations. Red = increase after
								congestion pricing; green = decrease.
							</p>
							<CbdRouteDeltaChart />
						</div>
					{/if}
				</div>
			</section>
		{/each}

		<!-- Final spacer -->
		<div class="h-screen"></div>
	</div>
</div>

<style>
	/* Hide the default scrollbar */
	:global(html) {
		scrollbar-width: none; /* Firefox */
		-ms-overflow-style: none; /* Internet Explorer 10+ */
	}

	:global(html::-webkit-scrollbar) {
		width: 0;
		height: 0;
		display: none; /* Webkit browsers */
	}

	/* Smooth scrolling behavior */
	:global(html) {
		scroll-behavior: smooth;
	}
</style>
