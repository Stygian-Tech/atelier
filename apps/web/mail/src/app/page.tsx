import { MailWorkspace } from "@/components/mail/MailWorkspace";
import { getAppEnv } from "@/lib/appEnv";

export default function Page() {
  return <MailWorkspace appEnv={getAppEnv()} />;
}
