"use client";

import { QueryClient } from "@tanstack/react-query";

const STALE_TIME_MILLISECONDS = 60_000;
const GC_TIME_MILLISECONDS = 5 * 60_000;

function createQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      mutations: {
        retry: 0,
      },
      queries: {
        refetchOnWindowFocus: false,
        retry: 1,
        staleTime: STALE_TIME_MILLISECONDS,
        gcTime: GC_TIME_MILLISECONDS,
      },
    },
  });
}

let browserQueryClient: QueryClient | undefined;

export function getQueryClient(): QueryClient {
  if (typeof window === "undefined") return createQueryClient();

  browserQueryClient ??= createQueryClient();
  return browserQueryClient;
}

export function clearQueryCache() {
  getQueryClient().clear();
}
