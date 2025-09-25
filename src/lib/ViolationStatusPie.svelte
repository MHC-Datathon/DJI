<script lang="ts">
	import { onMount } from 'svelte';
	import Chart from 'chart.js/auto';
	import type { Chart as ChartType } from 'chart.js';
	import data from '$lib/assets/violation_status_summary.json';
	import manifest from '$lib/assets/violations_status_manifest.json';

	let canvas: HTMLCanvasElement | null = null;
	let chart: ChartType | null = null;

	onMount(() => {
		if (!canvas) return;

		const labels = data.map((d) => d['Violation Status']);
		const counts = data.map((d) => d.count);

		// build a mapping from status -> hex color from the manifest
		const manifestColor: Record<string, string> = {};
		for (const item of manifest as Array<{ status: string; color: number[] }>) {
			const [r, g, b] = item.color;
			manifestColor[item.status] = `rgb(${r}, ${g}, ${b})`;
		}

		const fallbackColors = [
			// '#4CAF50',
			// '#FF9800',
			'#F44336'
			// '#2196F3',
			// '#9C27B0',
			// '#FFC107',
			// '#607D8B'
		];

		const backgroundColor = labels.map(
			(lbl, i) => manifestColor[lbl] ?? fallbackColors[i % fallbackColors.length]
		);

		chart = new Chart(canvas, {
			type: 'pie',
			data: {
				labels,
				datasets: [
					{
						data: counts,
						backgroundColor,
						borderColor: '#ffffff',
						borderWidth: 1
					}
				]
			},
			options: {
				responsive: true,
				maintainAspectRatio: false,
				plugins: {
					legend: {
						position: 'top'
					},
					tooltip: {
						callbacks: {
							label: (ctx) => {
								const label = ctx.label ?? '';
								const value = ctx.parsed ?? 0;
								const total = counts.reduce((s, v) => s + v, 0);
								const pct = ((value / total) * 100).toFixed(1);
								return `${label}: ${value.toLocaleString()} (${pct}%)`;
							}
						}
					}
				}
			}
		});

		return () => {
			chart?.destroy();
			chart = null;
		};
	});
</script>

<div class="h-64 w-full">
	<canvas bind:this={canvas} />
</div>

<!-- <style>
	.chart-container {
		position: relative;
		width: 100%;
		height: 100%;
	}
</style> -->
