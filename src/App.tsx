
async function auth(
  email: string,
  password: string,
  signup: boolean,
  name: string,
  role: string
) {
  if (!supabase) {
    setNotice('Connect Supabase first using the setup guide.');
    return;
  }

  const redirectUrl =
    `${window.location.origin}/potatomarket/`;

  const result = signup
    ? await supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: redirectUrl,
          data: {
            full_name: name,
            account_type: role
          }
        }
      })
    : await supabase.auth.signInWithPassword({
        email,
        password
      });

  if (result.error) {
    setNotice(result.error.message);
    return;
  }

  setUser(result.data.session?.user ?? null);

  setModal(null);

  if (signup) {
    setNotice(
      result.data.session
        ? 'Account created successfully.'
        : 'Account created. Please check your email and confirm your account.'
    );
  } else {
    setNotice('Welcome back.');
  }
}
