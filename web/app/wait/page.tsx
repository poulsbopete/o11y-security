import type { Metadata } from "next";
import { WaitingRoom } from "./waiting-room";

export const metadata: Metadata = {
  title: "Lab briefing — Observability ↔ Security",
  description:
    "Story deck while the Instruqt sandbox or Kibana proxy comes up. Same slides as the GitHub Pages site, framed for waiting.",
};

export default function WaitPage() {
  return <WaitingRoom />;
}
