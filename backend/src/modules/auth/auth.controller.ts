import type { RequestHandler } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { AppError } from '../../utils/appError';
import type { AuthService } from './auth.service';
import type { ActivationService } from './activation.service';

export function createActivationController(service: ActivationService) {
  const request: RequestHandler = asyncHandler(async (req, res) => {
    const { tenantCode, phone } = req.body;
    const result = await service.request(tenantCode, phone);
    // Same answer whether or not the phone belongs to an account awaiting activation.
    res.status(200).json({ success: true, data: { sent: true, ...result } });
  });

  const complete: RequestHandler = asyncHandler(async (req, res) => {
    const { tenantCode, phone, code, password } = req.body;
    const result = await service.complete(tenantCode, phone, code, password);
    res.status(200).json({ success: true, data: result });
  });

  return { request, complete };
}

export function createAuthController(service: AuthService) {
  const login: RequestHandler = asyncHandler(async (req, res) => {
    const { tenantCode, phone, password } = req.body;
    const result = await service.login(tenantCode, phone, password);
    res.status(200).json({ success: true, data: result });
  });

  const refresh: RequestHandler = asyncHandler(async (req, res) => {
    const { refreshToken } = req.body;
    const result = await service.refresh(refreshToken);
    res.status(200).json({ success: true, data: result });
  });

  const logout: RequestHandler = asyncHandler(async (req, res) => {
    const { refreshToken, deviceId } = req.body;
    await service.logout(refreshToken, deviceId);
    res.status(200).json({ success: true, data: {} });
  });

  const logoutAll: RequestHandler = asyncHandler(async (req, res) => {
    if (!req.auth) {
      throw new AppError(401, 'UNAUTHORIZED', 'Authentication required');
    }
    await service.logoutAll(req.auth.userId);
    res.status(200).json({ success: true, data: {} });
  });

  const me: RequestHandler = asyncHandler(async (req, res) => {
    if (!req.auth) {
      throw new AppError(401, 'UNAUTHORIZED', 'Authentication required');
    }
    const user = await service.getUserById(req.auth.userId);
    res.status(200).json({ success: true, data: user });
  });

  return { login, refresh, logout, logoutAll, me };
}
