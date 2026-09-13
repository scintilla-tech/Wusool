import { describe, it, expect } from 'vitest';
import {
  uuidSchema,
  emailSchema,
  saudiPhoneSchema,
  normalizeSaudiPhone,
  nameSchema,
  latitudeSchema,
  longitudeSchema,
  isoDateSchema,
  paginationSchema,
} from '../src/validation/common';

describe('validation utilities', () => {
  describe('uuidSchema', () => {
    it('accepts a valid UUID', () => {
      expect(uuidSchema.parse('123e4567-e89b-12d3-a456-426614174000')).toBe(
        '123e4567-e89b-12d3-a456-426614174000',
      );
    });
    it('rejects an invalid UUID', () => {
      expect(() => uuidSchema.parse('not-a-uuid')).toThrow();
    });
  });

  describe('emailSchema', () => {
    it('accepts and lowercases a valid email', () => {
      expect(emailSchema.parse('  User@Example.COM ')).toBe('user@example.com');
    });
    it('rejects an invalid email', () => {
      expect(() => emailSchema.parse('not-an-email')).toThrow();
    });
  });

  describe('saudiPhoneSchema / normalizeSaudiPhone', () => {
    it('normalizes a leading-zero local number', () => {
      expect(normalizeSaudiPhone('0551234567')).toBe('+966551234567');
    });
    it('normalizes a country-code number', () => {
      expect(normalizeSaudiPhone('+966551234567')).toBe('+966551234567');
    });
    it('normalizes a number with spaces and dashes', () => {
      expect(saudiPhoneSchema.parse(' +966 55 123 4567 ')).toBe('+966551234567');
    });
    it('rejects a non-Saudi mobile number', () => {
      expect(() => saudiPhoneSchema.parse('+11234567890')).toThrow();
    });
    it('rejects a landline number', () => {
      expect(() => saudiPhoneSchema.parse('0112345678')).toThrow();
    });
  });

  describe('nameSchema', () => {
    it('accepts English names', () => {
      expect(nameSchema.parse('Sarah')).toBe('Sarah');
    });
    it('accepts Arabic names', () => {
      expect(nameSchema.parse('سارة')).toBe('سارة');
    });
    it('rejects names with digits', () => {
      expect(() => nameSchema.parse('Sarah2')).toThrow();
    });
    it('rejects empty names', () => {
      expect(() => nameSchema.parse('   ')).toThrow();
    });
  });

  describe('coordinates', () => {
    it('coerces numeric strings and validates latitude', () => {
      expect(latitudeSchema.parse('24.71')).toBe(24.71);
      expect(() => latitudeSchema.parse('91')).toThrow();
    });
    it('validates longitude range', () => {
      expect(() => longitudeSchema.parse('-181')).toThrow();
      expect(longitudeSchema.parse('45')).toBe(45);
    });
    it('rejects empty coordinates instead of coercing to 0', () => {
      expect(() => latitudeSchema.parse('')).toThrow();
      expect(() => longitudeSchema.parse('')).toThrow();
      expect(() => latitudeSchema.parse(null)).toThrow();
    });
  });

  describe('isoDateSchema', () => {
    it('coerces an ISO date string', () => {
      const parsed = isoDateSchema.parse('2026-09-13T08:00:00.000Z');
      expect(parsed instanceof Date).toBe(true);
    });
    it('rejects an invalid date', () => {
      expect(() => isoDateSchema.parse('not-a-date')).toThrow();
    });
    it('rejects an empty date', () => {
      expect(() => isoDateSchema.parse('')).toThrow();
    });
  });

  describe('paginationSchema', () => {
    it('applies defaults', () => {
      expect(paginationSchema.parse({})).toEqual({ page: 1, limit: 20 });
    });
    it('coerces string inputs', () => {
      expect(paginationSchema.parse({ page: '2', limit: '5' })).toEqual({ page: 2, limit: 5 });
    });
    it('rejects limit above max', () => {
      expect(() => paginationSchema.parse({ limit: 101 })).toThrow();
    });
    it('rejects unexpected properties', () => {
      expect(() => paginationSchema.parse({ page: 1, limit: 5, sort: 'x' })).toThrow();
    });
  });
});
