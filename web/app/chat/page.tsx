import { AnimatedAIChat } from "@/components/ui/animated-ai-chat";

/** Subtle stock backdrop (Earth / tech) — component itself is icon + gradient only. */
const CHAT_BACKDROP =
  "linear-gradient(to bottom, rgba(10,10,11,0.94), rgba(10,10,11,0.98)), url(https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=1920&q=80)";

export default function ChatDemoPage() {
  return (
    <div
      className="lab-bg min-h-screen w-full overflow-x-hidden bg-[#0A0A0B] bg-cover bg-center"
      style={{ backgroundImage: CHAT_BACKDROP }}
    >
      <AnimatedAIChat />
    </div>
  );
}
