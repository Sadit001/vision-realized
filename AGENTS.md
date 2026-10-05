<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->

# Project rules

- The GitHub repo Sadit001/vision-made-real is the source of truth for the existing app; reproduce it faithfully before redesigns. Why: user requires preservation.
- Letter data lives in Lovable Cloud tables `profiles` and `messages`; anonymous sends go through public server fns in src/lib/letters.functions.ts that resolve the recipient via a security-definer RPC. Why: profiles stay private from anonymous visitors.
