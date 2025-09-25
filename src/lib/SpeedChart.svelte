<script lang="ts">
	import {
		Chart,
		LineController,
		LineElement,
		PointElement,
		LinearScale,
		TimeScale,
		Tooltip,
		Legend,
		Filler,
		Title
	} from 'chart.js';
	import annotationPlugin from 'chartjs-plugin-annotation';
	import 'chartjs-adapter-date-fns';
	import zoomPlugin from 'chartjs-plugin-zoom';

	// Register Chart.js components and plugins once
	Chart.register(
		LineController,
		LineElement,
		PointElement,
		LinearScale,
		TimeScale,
		Tooltip,
		Legend,
		Filler,
		Title,
		annotationPlugin,
		zoomPlugin
	);

	/**
	 * Props
	 * - routeId: current route to display
	 * - dataByRoute: Map of route_id -> array of { ts: number (ms), speed: number, speed_3m?: number }
	 * - aceTsByRoute: Map of route_id -> ACE implementation timestamp in ms (optional)
	 */
	let {
		routeId,
		dataByRoute,
		aceTsByRoute,
		height = 220
	} = $props<{
		routeId?: string;
		dataByRoute: Map<string, Array<{ ts: number; speed: number; speed_3m?: number }>>;
		aceTsByRoute: Map<string, number>;
		height?: number;
	}>();

	let canvas = $state<HTMLCanvasElement | null>(null);
	// Chart instance must NOT be a $state reactive value — updating it inside
	// an effect would cause an effect-update loop. Use a plain local variable.
	let chart: Chart | null = null;

	function buildConfig(route: string) {
		const series = dataByRoute.get(route) ?? [];
		// Build datasets as XY points
		const primary = series.map((d) => ({ x: d.ts, y: d.speed }));
		const rolling = series
			.filter((d) => d.speed_3m != null)
			.map((d) => ({ x: d.ts, y: d.speed_3m as number }));

		const aceTs = aceTsByRoute?.get?.(route);

		// determine data time bounds for x-axis so labels aren't overcrowded
		let minTs: number | undefined = undefined;
		let maxTs: number | undefined = undefined;
		if (series.length) {
			minTs = Math.min(...series.map((d) => d.ts));
			maxTs = Math.max(...series.map((d) => d.ts));
		}
		// add paddings: small right padding for non-ACE routes, and a larger focus window around ACE
		const rightPadding = 1000 * 60 * 60 * 24 * 14; // 14 days
		const focusPadding = 1000 * 60 * 60 * 24 * 365; // 180 days before/after ACE

		// Compute axis bounds: include series bounds and ensure we show area around aceTs when present
		let axisMin: number | undefined = minTs;
		let axisMax: number | undefined = maxTs != null ? maxTs + rightPadding : undefined;
		if (aceTs) {
			// ensure we have a window before and after the ACE implementation date
			const aceWindowMin = aceTs - focusPadding;
			const aceWindowMax = aceTs + focusPadding;
			axisMin = axisMin != null ? Math.min(axisMin, aceWindowMin) : aceWindowMin;
			axisMax = axisMax != null ? Math.max(axisMax, aceWindowMax) : aceWindowMax;
		}

		return {
			type: 'line' as const,
			data: {
				datasets: [
					{
						label: 'Avg speed',
						data: primary,
						borderColor: '#1f77b4',
						backgroundColor: 'rgba(31, 119, 180, 0.15)',
						fill: false,
						borderWidth: 2,
						pointRadius: 0,
						tension: 0.15
					},
					{
						label: '3-month rolling',
						data: rolling,
						borderColor: '#ff7f0e',
						backgroundColor: 'transparent',
						borderDash: [6, 3],
						pointRadius: 0,
						borderWidth: 2,
						tension: 0.15
					}
				]
			},
			options: {
				parsing: false,
				responsive: true,
				maintainAspectRatio: false,
				plugins: {
					legend: { position: 'top' as const, labels: { usePointStyle: true } },
					title: { display: true, text: `Route ${route} speed over time` },
					tooltip: { mode: 'index' as const, intersect: false },
					zoom: {
						zoom: {
							wheel: {
								enabled: true
							},
							pinch: {
								enabled: true
							},
							pan: {
								enabled: true
								// modifierKey: 'ctrl',
							},
							mode: 'x'
						}
					},
					// chartjs-plugin-annotation v2 expects an `annotation` object with an `annotations` map.
					annotation: aceTs
						? {
								annotations: {
									aceLine: {
										type: 'line',
										xMin: aceTs,
										xMax: aceTs,
										borderColor: '#dc2626',
										borderDash: [8, 6],
										borderWidth: 2,
										label: {
											display: true,
											content: 'ACE',
											rotation: -90,
											backgroundColor: 'rgba(220,38,38,0.85)',
											color: 'white',
											position: 'end'
										}
									}
								}
							}
						: undefined
				},
				scales: {
					x: {
						type: 'time' as const,
						time: { unit: 'month' as const },
						// reduce tick density and enable intelligent skipping
						ticks: { maxRotation: 0, autoSkip: true, maxTicksLimit: 6 },
						// constrain visible range to the computed axis bounds (includes ACE padding)
						min: axisMin,
						max: axisMax,
						grid: { color: 'rgba(148,163,184,0.2)' }
					},
					y: {
						beginAtZero: false,
						title: { display: true, text: 'mph' },
						grid: { color: 'rgba(148,163,184,0.2)' }
					}
				},
				interaction: { mode: 'nearest' as const, intersect: false }
			}
		};
	}

	$effect(() => {
		// Rebuild or update chart when route or data changes
		const r = routeId;
		const el = canvas;
		if (!el || !r) return;

		const cfg = buildConfig(r);
		if (!chart) {
			chart = new Chart(el.getContext('2d')!, cfg as any);
		} else {
			// Update in place for smoother transitions
			chart.options = cfg.options as any;
			chart.data = cfg.data as any;
			chart.update('none');
		}

		return () => {
			// Cleanup on route change and unmount
			if (chart) {
				chart.destroy();
				chart = null;
			}
		};
	});
</script>

<div style="height: {height}px" class="w-full">
	{#if routeId}
		<canvas bind:this={canvas}></canvas>
	{:else}
		<div class="flex h-full items-center justify-center text-sm text-slate-500">
			Click a route to see speeds
		</div>
	{/if}
</div>

<style>
	:global(.chartjs-render-monitor) {
		/* ensure responsive canvas fills parent */
		width: 100% !important;
		height: 100% !important;
	}
</style>
