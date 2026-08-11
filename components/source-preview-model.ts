export type PreviewField = { pageNumber: number; label: string };

export function citedPreviewFields<T extends PreviewField>(fields: T[], citation: { page: number; field: string }): T[] {
  return fields.filter((field) => field.pageNumber === citation.page && field.label === citation.field);
}
