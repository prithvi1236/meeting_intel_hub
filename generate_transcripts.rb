require 'fileutils'

# Create a directory for the test files
dir = "test_transcripts"
FileUtils.mkdir_p(dir)

puts "📂 Creating test transcripts in ./#{dir}..."

# File 1: Standard TXT (Focus: Decisions and Action Items)
File.write("#{dir}/1_product_roadmap_q3.txt", <<~TEXT
Meeting Date: 2026-05-12
Project: Project Zephyr Roadmap
Participants: Sarah (Product), Marcus (Engineering), Elena (Design)

Sarah: Alright team, let's look at the Q3 roadmap. The big elephant in the room is the new AI Copilot feature. Sales is screaming for it, but I need to know if it's actually feasible.
Marcus: Honestly, Sarah, I'm getting really frustrated with these arbitrary sales deadlines. We still have a mountain of technical debt from the database migration. If we try to shove the Copilot feature into Q3, the core app performance is going to suffer. It's too risky.
Elena: I agree with Marcus on the risk, but the user testing we did last week was phenomenal. Users absolutely loved the Copilot concept. It could double our engagement metrics.
Sarah: Okay, I hear you both. Marcus, what if we delay the Mobile Dashboard update? We can push that entirely to Q4. Would that free up enough backend resources to build a safe MVP of the Copilot?
Marcus: If we drop the Mobile Dashboard... yeah. Actually, yes. That changes things. That gives my team at least three extra weeks. I feel much better about that approach.
Sarah: Great. Let's make that the official decision: We are delaying the Mobile Dashboard to Q4 to prioritize the AI Copilot MVP in Q3.
Marcus: I can get behind that.
Sarah: Perfect. So for next steps: Marcus, I need you to scope out the backend architecture for the Copilot and have that document ready by this Friday. Elena, can you please share the finalized UI mockups for the chat interface by Wednesday?
Elena: You got it. I'll drop them in the Slack channel by Wednesday end of day.
Marcus: And I'll have the architecture doc ready by Friday morning.
Sarah: Awesome. Thanks everyone.
TEXT
)

# File 2: WebVTT format (Focus: Timestamps and Sentiment/Conflict Analysis)
File.write("#{dir}/2_client_escalation_widgetcorp.vtt", <<~TEXT
WEBVTT

00:00:00.000 --> 00:00:04.500
<v Alex> This is an absolute disaster. WidgetCorp just called me screaming.

00:00:05.000 --> 00:00:09.200
<v Alex> Their entire checkout flow has been down for two hours because of our API outage.

00:00:09.500 --> 00:00:14.000
<v Priya> Look, Alex, I understand they are upset, but yelling at me doesn't fix the server.

00:00:14.200 --> 00:00:20.100
<v Priya> We pushed the v2.4 patch last night, and it introduced an aggressive rate-limiting bug that we didn't catch in staging.

00:00:20.500 --> 00:00:24.000
<v David> Okay, let's take a breath. Blame doesn't matter right now. Fixes matter. Priya, what is the fastest resolution?

00:00:24.500 --> 00:00:30.000
<v Priya> The fastest thing is to completely roll back to v2.3. It will take the system offline for about five minutes, but it will stabilize the API.

00:00:30.500 --> 00:00:33.000
<v David> Do it. We are making the decision right now to roll back to v2.3.

00:00:33.200 --> 00:00:38.500
<v Priya> Understood. Actioning the rollback now. It will be fully completed by 2:00 PM today.

00:00:39.000 --> 00:00:44.000
<v David> Alex, I need you to draft the formal incident report and send it to the WidgetCorp CTO by EOD today.

00:00:44.500 --> 00:00:50.000
<v Alex> Will do. I'll also offer them a 15% discount on next month's invoice to smooth this over.

00:00:50.500 --> 00:00:55.000
<v David> Good call. I'll approve that. I will process the credit memo for WidgetCorp by tomorrow morning.
TEXT
)

# File 3: Cross-meeting reference (Focus: Chatbot RAG testing)
File.write("#{dir}/3_engineering_sync_copilot.txt", <<~TEXT
Meeting Date: 2026-05-16
Project: Project Zephyr Roadmap
Participants: Sarah (Product), Marcus (Engineering)

Sarah: Hey Marcus, just doing a quick sync. Did you manage to finish that task from Tuesday?
Marcus: Yeah, the Copilot backend architecture doc is done. I sent you the link this morning.
Sarah: Awesome, thank you. So, looking at your architecture, we need to make a call on the LLM provider. Are we going with an open-source local model or an external API like OpenAI?
Marcus: If we want to hit that Q3 deadline we agreed on, we have to go with OpenAI. Running a local model requires us to spin up dedicated GPU clusters, and the latency is still too high for a chat interface. OpenAI is plug-and-play.
Sarah: Makes sense. Let's decide to use OpenAI for the Q3 MVP. We can always re-evaluate local models next year if costs get too high.
Marcus: Sounds good to me.
Sarah: Alright, since we are using OpenAI, I need to get the lawyers involved. I will draft the legal terms for the data privacy usage and send them to Legal by next Monday.
Marcus: Perfect. Let me know when they approve it so I can grab the API keys.
TEXT
)

puts "✅ Successfully created 3 transcript files!"
puts "You can now upload these through your Rails frontend."
