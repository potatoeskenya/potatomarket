import { useEffect, useMemo, useState } from 'react';
import type { User } from '@supabase/supabase-js';
import {
  ArrowRight,
  BadgeCheck,
  CircleHelp,
  Leaf,
  MessageCircle,
  Menu,
  Package,
  Search,
  ShieldCheck,
  ShoppingBasket,
  ShoppingCart,
  Sprout,
  Star,
  Truck,
  Users,
  X
} from 'lucide-react';
import { configured, supabase, KENYAN_COUNTIES, type Product } from './lib';
import Dashboard from './Dashboard';

const demo: Product[] = [
  {
    id: 'd1',
    title: 'Certified Shangi Seed Potatoes',
    category: 'Certified seeds',
    variety: 'Shangi',
    price: 4800,
    unit: '50 kg bag',
    quantity: 120,
    county: 'Nakuru',
    description:
      'Quality planting seed. Request current certification evidence before purchase.',
    image_url:
      'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=900&q=85',
    is_certified: false,
    seller_id: 's1',
    profiles: {
      full_name: 'Kuresoi Seed Growers',
      farm_name: 'Green Hills Farm',
      county: 'Nakuru',
      rating: 4.9
    }
  },
  {
    id: 'd2',
    title: 'Fresh Ware Potatoes',
    category: 'Ware potatoes',
    variety: 'Shangi',
    price: 2600,
    unit: '50 kg bag',
    quantity: 85,
    county: 'Uasin Gishu',
    description:
      'Freshly harvested ware potatoes for homes, shops and institutions.',
    image_url:
      'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=900&q=85',
    is_certified: false,
    seller_id: 's2',
    profiles: {
      full_name: 'Eldoret Fresh Produce',
      farm_name: 'Highland Harvest',
      county: 'Uasin Gishu',
      rating: 4.8
    }
  },
  {
    id: 'd3',
    title: 'Unica Certified Seed Potatoes',
    category: 'Certified seeds',
    variety: 'Unica',
    price: 5200,
    unit: '50 kg bag',
    quantity: 64,
    county: 'Nyandarua',
    description:
      'Seed potato listing. Certification status is subject to administrator verification.',
    image_url:
      'https://images.unsplash.com/photo-1590165482129-1b8b27698780?auto=format&fit=crop&w=900&q=85',
    is_certified: false,
    seller_id: 's3',
    profiles: {
      full_name: 'Nyandarua Potato Hub',
      farm_name: 'Mawingu Farm',
      county: 'Nyandarua',
      rating: 4.7
    }
  },
  {
    id: 'd4',
    title: 'Bulk Markies Ware Potatoes',
    category: 'Ware potatoes',
    variety: 'Markies',
    price: 2900,
    unit: '50 kg bag',
    quantity: 300,
    county: 'Nairobi',
    description:
      'Bulk supply for retailers, restaurants and processors. Delivery can be arranged.',
    image_url:
      'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=900&q=85',
    is_certified: false,
    seller_id: 's4',
    profiles: {
      full_name: 'Central Produce Traders',
      farm_name: 'Central Produce',
      county: 'Nairobi',
      rating: 4.6
    }
  }
];

const money = (n: number) =>
  new Intl.NumberFormat('en-KE', {
    style: 'currency',
    currency: 'KES',
    maximumFractionDigits: 0
  }).format(n);

export default function App() {
  const [products, setProducts] = useState<Product[]>(demo);
  const [query, setQuery] = useState('');
  const [category, setCategory] = useState('All products');
  const [county, setCounty] = useState('All counties');
  const [modal, setModal] = useState<
    'login' | 'signup' | 'sell' | 'cart' | null
  >(null);
  const [user, setUser] = useState<User | null>(null);
  const [menu, setMenu] = useState(false);
  const [cart, setCart] = useState<Product[]>([]);
  const [notice, setNotice] = useState('');

  useEffect(() => {
    if (!supabase) return;

    supabase.auth.getSession().then(({ data, error }) => {
      if (error) {
        console.warn('Could not retrieve session:', error.message);
        return;
      }
      setUser(data.session?.user ?? null);
    });

    const {
      data: { subscription }
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
    });

    return () => subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!supabase) return;

    supabase
      .from('products')
      .select('*,profiles(full_name,farm_name,county,rating)')
      .eq('status', 'active')
      .order('created_at', { ascending: false })
      .then(({ data, error }) => {
        if (data) setProducts(data as Product[]);
        if (error) console.warn(error.message);
      });
  }, []);

  const filtered = useMemo(
    () =>
      products.filter(
        p =>
          (category === 'All products' || p.category === category) &&
          (county === 'All counties' || p.county === county) &&
          `${p.title} ${p.variety ?? ''} ${p.county} ${p.category}`
            .toLowerCase()
            .includes(query.toLowerCase())
      ),
    [products, category, county, query]
  );

  // Account registration and login.
  async function auth(
    email: string,
    password: string,
    signup: boolean,
    name: string,
    role: string
  ) {
    if (!supabase) {
      setNotice('Supabase is not configured. Please check the setup guide.');
      return;
    }

    // This must match the deployed GitHub Pages address.
    const redirectUrl = 'https://potatoeskenya.github.io/potatomarket/';

    try {
      if (signup) {
        const { data, error } = await supabase.auth.signUp({
          email: email.trim(),
          password,
          options: {
            emailRedirectTo: redirectUrl,
            data: {
              full_name: name.trim(),
              account_type: role
            }
          }
        });

        if (error) {
          setNotice(error.message);
          return;
        }

        if (data.session?.user) {
          setUser(data.session.user);
        }

        setModal(null);
        setNotice(
          data.session
            ? 'Account created successfully. Welcome to Kenya Potato Marketplace!'
            : 'Account created. Please check your email and click the confirmation link to activate your account.'
        );
        return;
      }

      const { data, error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password
      });

      if (error) {
        setNotice(error.message);
        return;
      }

      setUser(data.session?.user ?? null);
      setModal(null);
      setNotice('Welcome back to Kenya Potato Marketplace!');
    } catch (error) {
      console.error('Authentication error:', error);
      setNotice(
        'Unable to complete registration. Check your internet connection and try again.'
      );
    }
  }

  async function addProduct(form: FormData) {
    if (!supabase || !user) {
      setNotice('Sign in and connect Supabase to publish products.');
      return;
    }

    const { error } = await supabase.from('products').insert({
      seller_id: user.id,
      title: String(form.get('title') ?? ''),
      category: String(form.get('category') ?? ''),
      variety: String(form.get('variety') ?? '') || null,
      price: Number(form.get('price')),
      unit: String(form.get('unit') ?? ''),
      quantity: Number(form.get('quantity')),
      county: String(form.get('county') ?? ''),
      description: String(form.get('description') ?? ''),
      image_url: String(form.get('image_url') ?? '') || null,
      status: 'active'
    });

    if (error) {
      setNotice(error.message);
      return;
    }

    setModal(null);
    setNotice('Your listing has been submitted.');

    const { data, error: fetchError } = await supabase
      .from('products')
      .select('*,profiles(full_name,farm_name,county,rating)')
      .eq('status', 'active')
      .order('created_at', { ascending: false });

    if (fetchError) {
      console.warn(fetchError.message);
    } else if (data) {
      setProducts(data as Product[]);
    }
  }

  async function order(p: Product) {
    if (!supabase || !user) {
      setCart(current => [...current, p]);
      setModal('login');
      setNotice('Sign in to place an order.');
      return;
    }

    const { data, error } = await supabase.rpc('create_marketplace_order', {
      p_product_id: p.id,
      p_quantity: 1
    });

    if (error) {
      setNotice(error.message);
      return;
    }

    setNotice(
      `Order ${String(data).slice(0, 8)} created. Continue to secure checkout from your dashboard when payment is enabled.`
    );
  }

  async function contactSeller(p: Product) {
    if (!supabase || !user) {
      setModal('login');
      setNotice('Log in to message this seller securely.');
      return;
    }

    if (p.seller_id === user.id) {
      setNotice('This is your own listing.');
      return;
    }

    const { error } = await supabase.from('conversations').insert({
      buyer_id: user.id,
      seller_id: p.seller_id,
      product_id: p.id
    });

    if (error) {
      setNotice(error.message);
    } else {
      setNotice(
        'Conversation created. Open your dashboard to chat with the seller.'
      );
    }
  }

  if (user) {
    return (
      <Dashboard
        user={user}
        onExit={async () => {
          await supabase?.auth.signOut();
          setUser(null);
        }}
        notify={setNotice}
      />
    );
  }

  return (
    <div className="app">
      <header className="top">
        <div className="nav wrap">
          <a className="brand" href="#home">
            <span className="brand-icon">
              <Sprout size={25} />
            </span>
            <span>
              <b>KENYA POTATO</b>
              <small>FARMERS MARKETPLACE</small>
            </span>
          </a>

          <nav className={menu ? 'navlinks open' : 'navlinks'}>
            <a href="#market">Marketplace</a>
            <a href="#how">How it works</a>
            <a href="#community">Farmers hub</a>
            <a href="#trust">Buyer protection</a>
          </nav>

          <div className="nav-actions">
            <button
              className="iconbtn"
              aria-label="Cart"
              onClick={() => setModal('cart')}
            >
              <ShoppingCart size={19} />
              <i>{cart.length}</i>
            </button>

            {user ? (
              <button
                className="btn btn-light"
                onClick={() =>
                  setNotice(
                    'Your account dashboard is available after sign-in.'
                  )
                }
              >
                My account
              </button>
            ) : (
              <>
                <button className="login" onClick={() => setModal('login')}>
                  Log in
                </button>
                <button
                  className="btn btn-yellow"
                  onClick={() => setModal('signup')}
                >
                  Join free <ArrowRight size={16} />
                </button>
              </>
            )}

            <button
              className="mobile-menu"
              onClick={() => setMenu(!menu)}
              aria-label="Menu"
            >
              {menu ? <X /> : <Menu />}
            </button>
          </div>
        </div>
      </header>

      <main id="home">
        <section className="hero">
          <div className="hero-bg" />
          <div className="wrap hero-inner">
            <div className="hero-copy">
              <div className="eyebrow">
                <span /> KENYA'S POTATO MARKETPLACE
              </div>
              <h1>
                From the farm.
                <br />
                <em>To every table.</em>
              </h1>
              <p>
                Buy certified seed potatoes, source fresh ware potatoes and
                connect directly with trusted farmers across all 47 counties.
              </p>
              <div className="hero-buttons">
                <a className="btn btn-yellow btn-lg" href="#market">
                  Explore marketplace <ArrowRight size={18} />
                </a>
                <button
                  className="btn btn-outline btn-lg"
                  onClick={() => setModal('signup')}
                >
                  Become a seller
                </button>
              </div>
              <div className="hero-proof">
                <span>
                  <ShieldCheck size={17} /> Secure checkout
                </span>
                <span>
                  <BadgeCheck size={17} /> Verified listings
                </span>
                <span>
                  <Truck size={17} /> Nationwide delivery
                </span>
              </div>
            </div>

            <div className="hero-card">
              <div className="hero-card-top">
                <span>GROWING TOGETHER</span>
                <Leaf size={18} />
              </div>
              <div className="hero-stat">
                <b>47</b>
                <span>counties connected</span>
              </div>
              <div className="hero-stat-row">
                <div>
                  <b>Seeds</b>
                  <small>Certified listings</small>
                </div>
                <div>
                  <b>Ware</b>
                  <small>Fresh produce</small>
                </div>
                <div>
                  <b>Trade</b>
                  <small>Protected orders</small>
                </div>
              </div>
              <div className="hero-card-foot">
                A stronger market for every potato farmer.
              </div>
            </div>
          </div>
        </section>

        <section className="trust-strip">
          <div className="wrap trust-grid">
            <div>
              <ShieldCheck />
              <span>
                <b>Protected transactions</b>
                <small>Payment and order tracking</small>
              </span>
            </div>
            <div>
              <BadgeCheck />
              <span>
                <b>Trust-led marketplace</b>
                <small>Verified profiles and reviews</small>
              </span>
            </div>
            <div>
              <Truck />
              <span>
                <b>Across Kenya</b>
                <small>Connect buyers and transporters</small>
              </span>
            </div>
            <div>
              <MessageCircle />
              <span>
                <b>Private messaging</b>
                <small>Keep conversations on-platform</small>
              </span>
            </div>
          </div>
        </section>

        <section className="section wrap" id="market">
          <div className="section-head">
            <div>
              <div className="eyebrow green">FIND WHAT YOU NEED</div>
              <h2>Shop the potato market</h2>
              <p>
                Discover trusted farmers, quality produce and planting
                materials.
              </p>
            </div>
            <button
              className="text-link"
              onClick={() => {
                setCategory('All products');
                setCounty('All counties');
                setQuery('');
              }}
            >
              View all listings <ArrowRight size={16} />
            </button>
          </div>

          <div className="market-tools">
            <div className="searchbox">
              <Search size={19} />
              <input
                value={query}
                onChange={e => setQuery(e.target.value)}
                placeholder="Search potatoes, varieties, farmers or counties..."
              />
            </div>
            <select
              value={category}
              onChange={e => setCategory(e.target.value)}
            >
              <option>All products</option>
              <option>Certified seeds</option>
              <option>Ware potatoes</option>
              <option>Farm inputs</option>
              <option>Transport</option>
            </select>
            <select value={county} onChange={e => setCounty(e.target.value)}>
              <option>All counties</option>
              {KENYAN_COUNTIES.map(c => (
                <option key={c}>{c}</option>
              ))}
            </select>
            <button className="btn btn-green" onClick={() => setModal('sell')}>
              + List a product
            </button>
          </div>

          <div className="category-pills">
            {[
              'All products',
              'Certified seeds',
              'Ware potatoes',
              'Farm inputs',
              'Transport'
            ].map(c => (
              <button
                key={c}
                className={category === c ? 'active' : ''}
                onClick={() => setCategory(c)}
              >
                {c}
              </button>
            ))}
          </div>

          <div className="product-grid">
            {filtered.map(p => (
              <article className="product" key={p.id}>
                <div className="product-img">
                  <img
                    src={
                      p.image_url ||
                      'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=900&q=80'
                    }
                    alt={p.title}
                  />
                  <span className="tag">{p.category}</span>
                  {p.is_certified && (
                    <span className="verified">
                      <BadgeCheck size={13} /> Certified
                    </span>
                  )}
                </div>
                <div className="product-body">
                  <div className="product-location">
                    <span>
                      <Leaf size={13} />
                      {p.county}
                    </span>
                    <span className="rating">
                      <Star size={13} fill="currentColor" />
                      {p.profiles?.rating?.toFixed(1) || 'New'}
                    </span>
                  </div>
                  <h3>{p.title}</h3>
                  <p className="variety">
                    {p.variety || 'Farm produce'} · {p.quantity} available
                  </p>
                  <div className="seller-line">
                    <span className="avatar">
                      {(
                        p.profiles?.farm_name ||
                        p.profiles?.full_name ||
                        'F'
                      ).slice(0, 1)}
                    </span>
                    <span>
                      {p.profiles?.farm_name ||
                        p.profiles?.full_name ||
                        'Marketplace seller'}
                    </span>
                  </div>
                  <div className="product-bottom">
                    <div>
                      <b>{money(p.price)}</b>
                      <small>/ {p.unit}</small>
                    </div>
                    <div className="product-actions">
                      <button
                        aria-label="Message seller"
                        className="message-seller"
                        onClick={() => contactSeller(p)}
                      >
                        <MessageCircle size={15} /> Chat
                      </button>
                      <button
                        aria-label="Order product"
                        onClick={() => order(p)}
                      >
                        <ShoppingBasket size={17} /> Order
                      </button>
                    </div>
                  </div>
                </div>
              </article>
            ))}
          </div>

          {filtered.length === 0 && (
            <div className="empty">
              <Package size={34} />
              <b>No listings found</b>
              <span>Try another search or county.</span>
            </div>
          )}
        </section>

        <section className="how section" id="how">
          <div className="wrap">
            <div className="center-head">
              <div className="eyebrow green">SIMPLE. SECURE. FAIR.</div>
              <h2>Trade with confidence</h2>
              <p>
                Every step is designed to help buyers and farmers transact
                with clarity.
              </p>
            </div>
            <div className="steps">
              <div>
                <span>01</span>
                <ShoppingBasket />
                <h3>Find your potatoes</h3>
                <p>
                  Compare varieties, prices, seller ratings and locations.
                </p>
              </div>
              <div>
                <span>02</span>
                <ShieldCheck />
                <h3>Pay securely</h3>
                <p>
                  Pay using the supported M-Pesa checkout and track your order.
                </p>
              </div>
              <div>
                <span>03</span>
                <Truck />
                <h3>Receive your order</h3>
                <p>
                  Coordinate delivery through private in-platform messaging.
                </p>
              </div>
              <div>
                <span>04</span>
                <Star />
                <h3>Confirm and review</h3>
                <p>
                  Confirm receipt to trigger seller payout, then leave a
                  verified review.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section className="community section wrap" id="community">
          <div className="community-copy">
            <div className="eyebrow green">MORE THAN A MARKETPLACE</div>
            <h2>
              One community.
              <br />
              <em>Shared growth.</em>
            </h2>
            <p>
              Connect with farmers, find farming partners, share opportunities,
              learn from one another and grow the potato industry together.
            </p>
            <div className="community-list">
              <span>
                <Users /> Farmer groups and partnerships
              </span>
              <span>
                <MessageCircle /> Community discussions and meetings
              </span>
              <span>
                <Sprout /> Farming projects and opportunities
              </span>
            </div>
            <button
              className="btn btn-green btn-lg"
              onClick={() => setModal('signup')}
            >
              Join the farmers hub <ArrowRight size={17} />
            </button>
          </div>
          <div className="community-photo">
            <img
              src="https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1100&q=85
              alt="Agricultural fields"
            />
            <div className="photo-note">
              <b>Growing stronger together</b>
              <small>Connecting Kenya's potato value chain</small>
            </div>
          </div>
        </section>

        <section className="trust-section section" id="trust">
          <div className="wrap trust-content">
            <div>
              <div className="eyebrow">BUYER CONFIDENCE</div>
              <h2>
                Your order.
                <br />
                Your confirmation.
              </h2>
              <p>
                Our intended transaction flow keeps order status, payment
                records and delivery confirmation visible. Funds are released
                to the seller only through an approved payout process after
                buyer confirmation.
              </p>
            </div>
            <div className="protection-card">
              <ShieldCheck size={34} />
              <h3>Clear and accountable trading</h3>
              <ul>
                <li>Payment status verified by provider callback</li>
                <li>Order and delivery status recorded</li>
                <li>Buyer confirmation recorded securely</li>
                <li>Dispute and refund support</li>
                <li>Seller payout audit trail</li>
              </ul>
            </div>
          </div>
        </section>

        <section className="cta wrap">
          <div>
            <div className="eyebrow">
              LET'S GROW KENYA'S POTATO INDUSTRY
            </div>
            <h2>Ready to buy, sell or grow?</h2>
            <p>Create your free account and join the marketplace.</p>
          </div>
          <button
            className="btn btn-yellow btn-lg"
            onClick={() => setModal('signup')}
          >
            Get started free <ArrowRight />
          </button>
        </section>
      </main>

      <footer>
        <div className="wrap footer-main">
          <div className="brand footer-brand">
            <span className="brand-icon">
              <Sprout />
            </span>
            <span>
              <b>KENYA POTATO</b>
              <small>FARMERS MARKETPLACE</small>
            </span>
          </div>
          <p>Connecting Kenya's potato farmers, buyers and communities.</p>
          <div className="footer-links">
            <a href="#market">Marketplace</a>
            <a href="#how">How it works</a>
            <a href="#community">Farmers hub</a>
            <a href="#trust">Buyer protection</a>
          </div>
        </div>
        <div className="wrap copyright">
          © {new Date().getFullYear()} Kenya Potato Farmers Marketplace. All
          rights reserved.
          <span>Built for Kenya's potato value chain.</span>
        </div>
      </footer>

      {notice && (
        <div className="toast" role="status">
          {notice}
          <button onClick={() => setNotice('')} aria-label="Close message">
            <X size={15} />
          </button>
        </div>
      )}

      {modal && (
        <div
          className="modal-backdrop"
          onMouseDown={e => {
            if (e.target === e.currentTarget) setModal(null);
          }}
        >
          <div className="modal">
            <button
              className="modal-close"
              onClick={() => setModal(null)}
              aria-label="Close dialog"
            >
              <X />
            </button>

            {modal === 'login' || modal === 'signup' ? (
              <AuthForm signup={modal === 'signup'} onSubmit={auth} />
            ) : modal === 'sell' ? (
              <SellForm
                onSubmit={addProduct}
                onClose={() => setModal(null)}
              />
            ) : (
              <div>
                <h2>Your basket</h2>
                {cart.length ? (
                  cart.map((p, i) => (
                    <p key={`${p.id}-${i}`}>
                      {p.title} — {money(p.price)}
                    </p>
                  ))
                ) : (
                  <p>
                    Your basket is empty. Choose a listing to get started.
                  </p>
                )}
                <button
                  className="btn btn-green full"
                  onClick={() => setModal('login')}
                >
                  Continue to checkout
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {!configured && (
        <div className="setup-banner">
          <CircleHelp size={16} />
          Preview mode: connect your Supabase project to activate accounts,
          live listings, orders and chat.
          <a href="README.md">Setup guide</a>
        </div>
      )}
    </div>
  );
}

function AuthForm({
  signup,
  onSubmit
}: {
  signup: boolean;
  onSubmit: (
    email: string,
    password: string,
    signup: boolean,
    name: string,
    role: string
  ) => void | Promise<void>;
}) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [role, setRole] = useState('buyer');

  return (
    <form
      onSubmit={e => {
        e.preventDefault();
        void onSubmit(email, password, signup, name, role);
      }}
    >
      <div className="eyebrow green">KENYA POTATO MARKETPLACE</div>

      <h2>{signup ? 'Create your free account' : 'Welcome back'}</h2>
      <p className="muted">
        {signup
          ? 'Join buyers and sellers from across Kenya.'
          : 'Log in to manage your marketplace activity.'}
      </p>

      {signup && (
        <>
          <label>
            Full name
            <input
              required
              value={name}
              onChange={e => setName(e.target.value)}
              placeholder="Your full name"
            />
          </label>
          <label>
            Account type
            <select value={role} onChange={e => setRole(e.target.value)}>
              <option value="buyer">Buyer</option>
              <option value="seller">Seller</option>
              <option value="both">Buyer and seller</option>
              <option value="transporter">Transporter</option>
            </select>
          </label>
        </>
      )}

      <label>
        Email address
        <input
          type="email"
          required
          value={email}
          onChange={e => setEmail(e.target.value)}
          placeholder="you@example.com"
        />
      </label>
      <label>
        Password
        <input
          type="password"
          minLength={8}
          required
          value={password}
          onChange={e => setPassword(e.target.value)}
          placeholder="At least 8 characters"
        />
      </label>

      <button className="btn btn-green full" type="submit">
        {signup ? 'Create account' : 'Log in'} <ArrowRight size={17} />
      </button>
    </form>
  );
}

function SellForm({
  onSubmit,
  onClose
}: {
  onSubmit: (form: FormData) => void | Promise<void>;
  onClose: () => void;
}) {
  return (
    <form
      onSubmit={e => {
        e.preventDefault();
        void onSubmit(new FormData(e.currentTarget));
      }}
    >
      <div className="eyebrow green">SELL ON THE MARKETPLACE</div>
      <h2>Create a listing</h2>

      <label>
        Product title
        <input
          name="title"
          required
          placeholder="e.g. Shangi certified seed potatoes"
        />
      </label>

      <div className="form-row">
        <label>
          Category
          <select name="category">
            <option>Certified seeds</option>
            <option>Ware potatoes</option>
            <option>Farm inputs</option>
            <option>Transport</option>
          </select>
        </label>
        <label>
          Variety
          <input name="variety" placeholder="Shangi, Unica..." />
        </label>
      </div>

      <div className="form-row">
        <label>
          Price (KES)
          <input name="price" type="number" min="1" required />
        </label>
        <label>
          Unit
          <input name="unit" required placeholder="50 kg bag" />
        </label>
      </div>

      <div className="form-row">
        <label>
          Quantity available
          <input name="quantity" type="number" min="1" required />
        </label>
        <label>
          County
          <select name="county">
            {KENYAN_COUNTIES.map(c => (
              <option key={c}>{c}</option>
            ))}
          </select>
        </label>
      </div>

      <label>
        Image URL
        <input name="image_url" type="url" placeholder="https://..." />
      </label>
      <label>
        Description
        <textarea name="description" rows={3} />
      </label>

      <p className="muted tiny">
        Seed certification is reviewed separately. Do not claim certification
        unless supported by valid evidence.
      </p>

      <button className="btn btn-green full" type="submit">
        Submit listing
      </button>
      <button
        type="button"
        className="btn btn-ghost full"
        onClick={onClose}
      >
        Cancel
      </button>
    </form>
  );
}
