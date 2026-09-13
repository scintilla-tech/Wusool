import type { NextFunction, Request, Response } from 'express';
import type { ZodTypeAny } from 'zod';

export interface ValidateSchemas {
  body?: ZodTypeAny;
  query?: ZodTypeAny;
  params?: ZodTypeAny;
}

/**
 * Strict request validation middleware. Parses and replaces the validated
 * (and coerced) values onto the request. Use `.strict()` schemas to reject
 * unexpected properties.
 *
 * `req.body` is a plain writable property, but Express defines `req.query`
 * and `req.params` as getter-only, so those are replaced via
 * `Object.defineProperty` rather than assignment.
 */
function replaceProperty(target: object, key: string, value: unknown): void {
  Object.defineProperty(target, key, {
    value,
    writable: true,
    enumerable: true,
    configurable: true,
  });
}

export function validate(schemas: ValidateSchemas) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    try {
      if (schemas.body) {
        req.body = schemas.body.parse(req.body);
      }
      if (schemas.query) {
        replaceProperty(req, 'query', schemas.query.parse(req.query));
      }
      if (schemas.params) {
        replaceProperty(req, 'params', schemas.params.parse(req.params));
      }
      next();
    } catch (err) {
      next(err);
    }
  };
}
