<script lang="ts">
	import { Chart, registerables } from 'chart.js';
	import { onMount } from 'svelte';
	import pre_post_summary from '$lib/assets/pre_post_summary.json';

	Chart.register(...registerables);

	export let maxRoutes = 15;
	export let sortBy: 'delta_mph' | 'pct_change' | 'route_id' = 'delta_mph';
	export let ascending = false;

	let chartCanvas: HTMLCanvasElement;
	let chart: Chart | null = null;

	const processData = () => {
		// Sort and limit data
		const sortedData = [...pre_post_summary]
			.sort((a, b) => {
				if (sortBy === 'route_id') {
					return ascending
						? a[sortBy].localeCompare(b[sortBy])
						: b[sortBy].localeCompare(a[sortBy]);
				}
				return ascending ? a[sortBy] - b[sortBy] : b[sortBy] - a[sortBy];
			})
			.slice(0, maxRoutes);

		const labels = sortedData.map((d) => d.route_id);
		const preAceData = sortedData.map((d) => d.pre_ace);
		const postAceData = sortedData.map((d) => d.post_ace);

		return { labels, preAceData, postAceData };
	};

	const createChart = () => {
		if (!chartCanvas) return;

		const { labels, preAceData, postAceData } = processData();

		if (chart) {
			chart.destroy();
		}

		chart = new Chart(chartCanvas, {
			type: 'bar',
			data: {
				labels,
				datasets: [
					{
						label: 'Pre-ACE Speed',
						data: preAceData,
						backgroundColor: 'rgba(59, 130, 246, 0.8)',
						borderColor: 'rgba(59, 130, 246, 1)',
						borderWidth: 1
					},
					{
						label: 'Post-ACE Speed',
						data: postAceData,
						backgroundColor: 'rgba(16, 185, 129, 0.8)',
						borderColor: 'rgba(16, 185, 129, 1)',
						borderWidth: 1
					}
				]
			},
			options: {
				responsive: true,
				maintainAspectRatio: false,
				interaction: {
					intersect: false,
					mode: 'index'
				},
				scales: {
					y: {
						beginAtZero: true,
						title: {
							display: true,
							text: 'Speed (mph)'
						},
						grid: {
							color: 'rgba(156, 163, 175, 0.2)'
						},
						ticks: {
							color: '#6b7280'
						}
					},
					x: {
						title: {
							display: true,
							text: 'Bus Route'
						},
						grid: {
							display: false
						},
						ticks: {
							color: '#6b7280',
							maxRotation: 45,
							minRotation: 0
						}
					}
				},
				plugins: {
					legend: {
						display: true,
						position: 'top',
						labels: {
							color: '#374151',
							usePointStyle: true,
							padding: 20
						}
					},
					tooltip: {
						backgroundColor: 'rgba(17, 24, 39, 0.9)',
						titleColor: '#f9fafb',
						bodyColor: '#f9fafb',
						borderColor: 'rgba(75, 85, 99, 0.3)',
						borderWidth: 1,
						cornerRadius: 8,
						callbacks: {
							afterBody: (context) => {
								const dataIndex = context[0].dataIndex;
								const routeData = processData();
								const originalData = pre_post_summary.find(
									(d) => d.route_id === routeData.labels[dataIndex]
								);
								if (originalData) {
									const delta = originalData.delta_mph;
									const pctChange = originalData.pct_change;
									return [`Δ Speed: ${delta.toFixed(2)} mph`, `% Change: ${pctChange.toFixed(1)}%`];
								}
								return [];
							}
						}
					}
				}
			}
		});
	};

	onMount(() => {
		createChart();
		return () => {
			if (chart) {
				chart.destroy();
			}
		};
	});

	// Reactive updates
	$: if (chart && (maxRoutes || sortBy || ascending !== undefined)) {
		createChart();
	}
</script>

<div class="chart-container">
	<canvas bind:this={chartCanvas} aria-label="Pre vs Post ACE Speed Comparison Bar Chart"></canvas>
</div>

<style>
	.chart-container {
		position: relative;
		height: 400px;
		width: 100%;
	}
</style>
