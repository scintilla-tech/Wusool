export function toPrismaPagination(page: number, limit: number): { skip: number; take: number } {
  return { skip: (page - 1) * limit, take: limit };
}

export interface Paginated<T> {
  items: T[];
  page: number;
  limit: number;
  total: number;
}
