<script lang="ts">
	import { onMount } from 'svelte';
	import Chart from 'chart.js/auto';
	import type { Chart as ChartType } from 'chart.js';
	import data from '$lib/assets/violations_cbd_by_route_summary.json';

	let canvas: HTMLCanvasElement | null = null;
	let chart: ChartType | null = null;

	onMount(() => {
		if (!canvas) return;

		// filter out invalid route_id entries and compute a safe signed delta from post - pre
		const rows = (data as Array<any>)
			.filter((r) => r.route_id)
			.map((r) => {
				const pre = Number(r.pre ?? 0);
				const post = Number(r.post ?? 0);
				// compute signed delta; guard against non-finite values
				const delta = Number.isFinite(post) && Number.isFinite(pre) ? post - pre : 0;
				return { route_id: String(r.route_id), pre, post, delta };
			})
			.sort((a, b) => Math.abs(b.delta) - Math.abs(a.delta))
			.slice(0, 25); // limit to top 25

		const labels = rows.map((r) => r.route_id);
		const deltas = rows.map((r) => r.delta);

		const background = deltas.map((d) =>
			d > 0 ? 'rgba(217,83,79,0.9)' : d < 0 ? 'rgba(92,184,92,0.9)' : 'rgba(150,150,150,0.9)'
		);

		chart = new Chart(canvas, {
			type: 'bar',
			data: {
				labels,
				datasets: [
					{
						label: 'Post - Pre violations',
						data: deltas,
						backgroundColor: background,
						borderColor: background,
						borderWidth: 1
					}
				]
			},
			options: {
				indexAxis: 'y',
				responsive: true,
				maintainAspectRatio: false,
				// scales: {
				// 	x: {
				// 		// ticks: { beginAtZero: true }
				// 	}
				// },
				plugins: {
					legend: { display: false },
					tooltip: {
						callbacks: {
							label: (ctx) => `${ctx.parsed.x?.toLocaleString?.() ?? ctx.parsed.x}`
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

<style>
	.chart-container {
		position: relative;
		width: 100%;
		height: 100%;
	}
</style>
