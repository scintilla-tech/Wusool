export interface OtpProvider {
  /** Deliver an OTP code to the given identifier (phone/email). */
  send(identifier: string, code: string): Promise<void>;
}

/**
 * Development/mock OTP provider. Does NOT send anything and does NOT log the
 * OTP (OTP must never be logged). In development the generated code is returned
 * in the registration response (`devOtp`) so the flow can be exercised end-to-end.
 */
export class MockOtpProvider implements OtpProvider {
  async send(_identifier: string, _code: string): Promise<void> {
    // no-op in development
  }
}
