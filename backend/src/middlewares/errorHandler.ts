import type { NextFunction, Request, Response } from 'express';
import type { Logger } from 'pino';
import { ZodError, type ZodIssue } from 'zod';
import { AppError } from '../utils/appError';

export function notFoundHandler(_req: Request, res: Response): void {
  res.status(404).json({
    success: false,
    error: { code: 'NOT_FOUND', message: 'Route not found' },
  });
}

/** Return only safe, non-data fields from Zod issues to avoid reflecting input values. */
function sanitizeIssues(issues: ZodIssue[]): Array<{ path: (string | number)[]; message: string }> {
  return issues.map((issue) => ({ path: issue.path, message: issue.message }));
}

interface HttpErrorLike {
  status?: number;
  statusCode?: number;
  type?: string;
}

/** Map body-parser errors (malformed JSON, oversized body, unsupported media type) to 4xx. */
function toBodyParserStatus(err: unknown): number | undefined {
  if (typeof err !== 'object' || err === null) {
    return undefined;
  }
  const { type, status, statusCode } = err as HttpErrorLike;
  const httpStatus = status ?? statusCode;
  if (type === 'entity.too.large' || httpStatus === 413) {
    return 413;
  }
  if (type === 'entity.parse.failed' || type === 'entity.verify.failed') {
    return 400;
  }
  if (type === 'encoding.unsupported' || httpStatus === 415) {
    return 415;
  }
  return undefined;
}

export function errorHandler(logger: Logger, isProduction: boolean) {
  return (err: unknown, req: Request, res: Response, next: NextFunction): void => {
    if (res.headersSent) {
      next(err);
      return;
    }

    const requestId = req.id ?? 'unknown';

    const bodyParserStatus = toBodyParserStatus(err);
    if (bodyParserStatus !== undefined) {
      logger.warn({ requestId }, 'Malformed or oversized request body');
      const code =
        bodyParserStatus === 413
          ? 'PAYLOAD_TOO_LARGE'
          : bodyParserStatus === 415
            ? 'UNSUPPORTED_MEDIA_TYPE'
            : 'INVALID_BODY';
      res.status(bodyParserStatus).json({
        success: false,
        error: { code, message: 'Invalid request body' },
      });
      return;
    }

    if (err instanceof AppError) {
      logger.warn({ err, requestId }, 'Handled application error');
      res.status(err.statusCode).json({
        success: false,
        error: {
          code: err.code,
          message: err.message,
          ...(isProduction || err.details === undefined ? {} : { details: err.details }),
        },
      });
      return;
    }

    if (err instanceof ZodError) {
      logger.warn({ requestId }, 'Validation error');
      res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid request',
          ...(isProduction ? {} : { details: sanitizeIssues(err.issues) }),
        },
      });
      return;
    }

    logger.error({ err, requestId }, 'Unhandled error');
    // Never leak internal details or stack traces in responses.
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Internal server error' },
    });
  };
}
