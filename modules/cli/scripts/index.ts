import type { BuildConfig } from "bun";

/**
 *  Default export in bundler.config.ts should be this type.
 *  It's needed because by default bun's config requires an entrypoint, but a default is set elseware so it should be optional in this case
 */
export type BundlerConfig = Partial<BuildConfig>;
