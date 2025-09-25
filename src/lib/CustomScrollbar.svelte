<script lang="ts">
	import { fly } from 'svelte/transition';

	interface Props {
		scrollProgress: number;
		chapterProgress: number;
		activeChapterIndex: number;
		totalChapters: number;
		chapterTitles: string[];
	}

	let { scrollProgress, chapterProgress, activeChapterIndex, totalChapters, chapterTitles }: Props =
		$props();

	let isHovered = $state(false);

	function scrollToProgress(targetProgress: number) {
		const scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
		const targetScrollTop = (targetProgress / 100) * scrollHeight;
		window.scrollTo({
			top: targetScrollTop,
			behavior: 'smooth'
		});
	}

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

<!-- Custom Scrollbar Track -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
	class="fixed top-4 right-4 bottom-4 z-20 w-2"
	onmouseenter={() => (isHovered = true)}
	onmouseleave={() => (isHovered = false)}
	transition:fly={{ x: 20, duration: 300, delay: 500 }}
>
	<!-- Background track -->
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<div
		class="bg-opacity-20 hover:bg-opacity-30 h-full w-full cursor-pointer rounded-full bg-white backdrop-blur-sm transition-all duration-300"
		class:w-3={isHovered}
		onclick={(e) => {
			const rect = e.currentTarget.getBoundingClientRect();
			const clickY = e.clientY - rect.top;
			const progress = (clickY / rect.height) * 100;
			scrollToProgress(Math.max(0, Math.min(100, progress)));
		}}
	>
		<!-- Progress fill -->
		<div
			class="rounded-full bg-gradient-to-b from-blue-400 to-blue-600 transition-all duration-500 ease-out"
			style:height="{scrollProgress}%"
		></div>
	</div>

	<!-- Chapter markers -->
	{#each chapterTitles as title, i}
		<button
			class="absolute cursor-pointer rounded-full border-2 backdrop-blur-sm transition-all duration-300 hover:scale-150"
			class:w-3={!isHovered}
			class:h-3={!isHovered}
			class:w-4={isHovered}
			class:h-4={isHovered}
			class:right-3={!isHovered}
			class:right-4={isHovered}
			class:bg-blue-500={i === activeChapterIndex}
			class:border-blue-500={i === activeChapterIndex}
			class:bg-white={i !== activeChapterIndex}
			class:border-white={i !== activeChapterIndex}
			class:bg-opacity-40={i !== activeChapterIndex}
			class:border-opacity-60={i !== activeChapterIndex}
			style:top="{(i / (totalChapters - 1)) * 100}%"
			style:transform="translateY(-50%)"
			onclick={() => scrollToChapter(i)}
			title="{i + 1}. {title}"
		>
			{#if isHovered && i === activeChapterIndex}
				<div
					class="bg-opacity-80 absolute top-1/2 left-full z-10 ml-2 -translate-y-1/2 transform rounded bg-black px-2 py-1 text-xs whitespace-nowrap text-white"
					transition:fly={{ x: -10, duration: 200 }}
				>
					{i + 1}. {title}
				</div>
			{/if}
		</button>
	{/each}
</div>
