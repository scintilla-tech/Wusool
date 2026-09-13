export type Maybe<T> = T | null | undefined;

export interface Paginated<T> {
  items: T[];
  page: number;
  limit: number;
  total: number;
}
