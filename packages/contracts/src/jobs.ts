export type DurableJobState = "pending" | "leased" | "succeeded" | "dead";

export interface DurableJob<Payload extends Record<string, unknown> = Record<string, unknown>> {
  id: string;
  tenantId: string;
  kind: string;
  idempotencyKey: string;
  payload: Payload;
  attempts: number;
  maxAttempts: number;
  state: DurableJobState;
  notBefore: string;
  leaseExpiresAt?: string;
}

export interface DurableJobStore {
  enqueue(job: Omit<DurableJob, "attempts" | "state">): Promise<{ id: string; inserted: boolean }>;
  lease(workerId: string, kinds: readonly string[], leaseSeconds: number): Promise<DurableJob | null>;
  complete(jobId: string, workerId: string): Promise<void>;
  retry(jobId: string, workerId: string, notBefore: string, errorCode: string): Promise<void>;
  deadLetter(jobId: string, workerId: string, errorCode: string): Promise<void>;
}
