import { AnimatedAIChat } from "@/components/ui/animated-ai-chat";

/** Local gradients only — avoids a third-party image fetch that can delay `load` or hang on strict networks. */
const CHAT_BACKDROP =
  "linear-gradient(to bottom, rgba(10,10,11,0.94), rgba(10,10,11,0.98)), radial-gradient(ellipse 120% 80% at 50% 18%, rgba(120,119,255,0.14), transparent 55%), radial-gradient(ellipse 90% 55% at 85% 88%, rgba(63,185,80,0.1), transparent 50%)";

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
