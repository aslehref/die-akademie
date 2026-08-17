/// <reference types="@sveltejs/kit" />

// Diese App laeuft rein im Browser (adapter-static, ssr = false).
// Es gibt keinen Server und damit auch keine App.Locals.

declare namespace App {
	interface PageData {
		user: import('@supabase/supabase-js').User | null;
		role: 'admin' | 'teacher' | 'viewer' | null;
	}

	// eslint-disable-next-line @typescript-eslint/no-empty-object-type
	interface Platform {}
}
