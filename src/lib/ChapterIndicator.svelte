<script lang="ts">
	import { fly, scale } from 'svelte/transition';

	interface Props {
		activeChapterIndex: number;
		activeChapterTitle: string;
		totalChapters: number;
		chapterTitles: string[];
		chapterProgress: number;
	}

	let {
		activeChapterIndex,
		activeChapterTitle,
		totalChapters,
		chapterTitles,
		chapterProgress
	}: Props = $props();

	let previousChapterIndex = $state(activeChapterIndex);
	let isChapterChanging = $derived(previousChapterIndex !== activeChapterIndex);

	$effect(() => {
		if (isChapterChanging) {
			setTimeout(() => {
				previousChapterIndex = activeChapterIndex;
			}, 300);
		}
	});

	function scrollToChapter(chapterIndex: number) {
		const sections = document.querySelectorAll('.story-section');
		const targetSection = sections[chapterIndex] as HTMLElement;
		if (targetSection) {
			targetSection.scrollIntoView({
				behavior: 'smooth',
				block: 'center'
			});
		}
	}
</script>

<!-- Chapter Progress Indicator -->
<div
	class="bg-opacity-90 fixed top-4 left-4 z-20 max-w-xs rounded-xl bg-white p-4 shadow-lg backdrop-blur-sm"
	transition:fly={{ y: -20, duration: 400, delay: 200 }}
>
	<!-- Current chapter info -->
	<div class="mb-3">
		<div class="mb-1 text-xs font-medium tracking-wider text-gray-500 uppercase">
			Chapter {activeChapterIndex + 1} of {totalChapters}
		</div>
		{#key activeChapterIndex}
			<div
				class="line-clamp-2 text-sm font-semibold text-gray-800"
				transition:fly={{ x: -20, duration: 300 }}
			>
				{activeChapterTitle}
			</div>
		{/key}
	</div>

	<!-- Progress within current chapter -->
	<div class="mb-3">
		<div class="h-2 w-full overflow-hidden rounded-full bg-gray-200">
			<div
				class="h-2 rounded-full bg-gradient-to-r from-blue-400 to-blue-600 transition-all duration-500 ease-out"
				style:width="{chapterProgress}%"
			></div>
		</div>
		<div class="mt-1 text-xs text-gray-500 transition-opacity duration-300">
			{chapterProgress}% through chapter
		</div>
	</div>

	<!-- Chapter dots navigation -->
	<div class="flex flex-wrap gap-1.5">
		{#each chapterTitles as title, i}
			<button
				class="group relative h-2.5 w-2.5 rounded-full transition-all duration-300 hover:scale-150"
				class:bg-blue-500={i === activeChapterIndex}
				class:bg-blue-200={i < activeChapterIndex}
				class:bg-gray-300={i > activeChapterIndex}
				class:scale-125={i === activeChapterIndex}
				onclick={() => scrollToChapter(i)}
				title="{i + 1}. {title}"
			>
				<!-- Tooltip on hover -->
				<div
					class="bg-opacity-80 pointer-events-none absolute bottom-full left-1/2 z-10 mb-2 -translate-x-1/2 transform rounded bg-black px-2 py-1 text-xs whitespace-nowrap text-white opacity-0 transition-opacity duration-200 group-hover:opacity-100"
				>
					{i + 1}. {title}
				</div>
			</button>
		{/each}
	</div>

	<!-- Remaining chapters counter -->
	<div class="mt-2 text-center text-xs text-gray-500 transition-all duration-300">
		{#key activeChapterIndex}
			<div transition:scale={{ duration: 200 }}>
				{#if activeChapterIndex < totalChapters - 1}
					{totalChapters - activeChapterIndex - 1} chapters remaining
				{:else}
					<span class="font-medium text-green-600">Story complete! 🎉</span>
				{/if}
			</div>
		{/key}
	</div>
</div>

<style>
	.line-clamp-2 {
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}
</style>
