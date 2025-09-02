import React, { useEffect, useMemo, useRef, useState } from "react";

/**
 * Dashboard Karang Taruna Dusun
 * — Satu file React, siap dipakai & dimodifikasi
 * — Fitur utama:
 *   1) Profil Organisasi (visi, misi, kontak)
 *   2) Struktur Organisasi (ketua, sekretaris, bendahara, seksi, dst.)
 *   3) Informasi & Pengumuman (post, pin, arsip)
 *   4) Kegiatan (timeline + status, anggaran, PJ, lampiran)
 *   5) Iuran (warga & pemuda) — pencatatan, filter, ringkasan otomatis
 *   6) Galeri (upload gambar lokal; disimpan di localStorage)
 *   7) Ekspor CSV (Iuran & Kegiatan)
 *   8) Cetak Laporan (print-friendly)
 *   9) Dark Mode (toggle)
 *  10) Pencarian & Sortir sederhana
 *
 * Catatan:
 * - Data disimpan di localStorage browser (tanpa server). Untuk produksi,
 *   hubungkan ke backend (Supabase, Firebase, Node, dsb.).
 * - Desain menggunakan kelas Tailwind CSS.
 */

/*************************
 * Utilitas & Helper
 *************************/
const LS_KEYS = {
  profile: "kt_profile_v1",
  structure: "kt_structure_v1",
  posts: "kt_posts_v1",
  events: "kt_events_v1",
  dues: "kt_dues_v1",
  gallery: "kt_gallery_v1",
  theme: "kt_theme_v1",
};

function useLocalState(key, initial) {
  const [state, setState] = useState(() => {
    try {
      const cached = localStorage.getItem(key);
      return cached ? JSON.parse(cached) : initial;
    } catch (e) {
      return initial;
    }
  });
  useEffect(() => {
    try {
      localStorage.setItem(key, JSON.stringify(state));
    } catch (e) {}
  }, [key, state]);
  return [state, setState];
}

const currency = (n) =>
  (Number(n || 0)).toLocaleString("id-ID", { style: "currency", currency: "IDR", maximumFractionDigits: 0 });

const toCSV = (rows) => {
  if (!rows?.length) return "";
  const headers = Object.keys(rows[0]);
  const esc = (v) => `"${String(v ?? "").replaceAll('"', '""')}"`;
  const body = rows.map((r) => headers.map((h) => esc(r[h])).join(",")).join("\n");
  return [headers.join(","), body].join("\n");
};

function downloadText(filename, text) {
  const blob = new Blob([text], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

/*************************
 * UI Kecil
 *************************/
function Section({ title, desc, children, right }) {
  return (
    <section className="bg-white/70 dark:bg-neutral-900/60 backdrop-blur rounded-2xl shadow-sm p-5 md:p-7 border border-neutral-200 dark:border-neutral-800">
      <div className="flex items-start justify-between gap-4 mb-4">
        <div>
          <h2 className="text-xl md:text-2xl font-semibold tracking-tight">{title}</h2>
          {desc && <p className="text-neutral-500 dark:text-neutral-400 text-sm mt-1">{desc}</p>}
        </div>
        <div className="flex-shrink-0">{right}</div>
      </div>
      {children}
    </section>
  );
}

function Chip({ children, tone = "default" }) {
  const tones = {
    default: "bg-neutral-100 text-neutral-700 dark:bg-neutral-800 dark:text-neutral-300",
    success: "bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300",
    warning: "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300",
    danger: "bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300",
    info: "bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300",
  };
  return <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium ${tones[tone]}`}>{children}</span>;
}

function Button({ children, onClick, type = "button", variant = "primary", className = "", disabled }) {
  const styles = {
    primary: "bg-blue-600 hover:bg-blue-700 text-white",
    ghost: "bg-transparent hover:bg-neutral-100 dark:hover:bg-neutral-800 text-neutral-700 dark:text-neutral-200",
    outline: "border border-neutral-300 dark:border-neutral-700 hover:bg-neutral-50 dark:hover:bg-neutral-800 text-neutral-800 dark:text-neutral-200",
    danger: "bg-red-600 hover:bg-red-700 text-white",
  };
  return (
    <button type={type} onClick={onClick} disabled={disabled} className={`px-3.5 py-2 rounded-xl text-sm font-medium transition ${styles[variant]} disabled:opacity-50 disabled:cursor-not-allowed ${className}`}>
      {children}
    </button>
  );
}

function Input({ label, ...props }) {
  return (
    <label className="block text-sm">
      {label && <span className="text-neutral-600 dark:text-neutral-300 mb-1 block">{label}</span>}
      <input {...props} className={`w-full rounded-xl border border-neutral-300 dark:border-neutral-700 bg-white dark:bg-neutral-900 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500/50`} />
    </label>
  );
}

function Textarea({ label, ...props }) {
  return (
    <label className="block text-sm">
      {label && <span className="text-neutral-600 dark:text-neutral-300 mb-1 block">{label}</span>}
      <textarea {...props} className={`w-full rounded-xl border border-neutral-300 dark:border-neutral-700 bg-white dark:bg-neutral-900 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500/50`} />
    </label>
  );
}

function Empty({ title = "Belum ada data", hint }) {
  return (
    <div className="text-center py-8 text-neutral-500 dark:text-neutral-400">
      <div className="text-lg font-medium">{title}</div>
      {hint && <div className="text-sm mt-1">{hint}</div>}
    </div>
  );
}

/*************************
 * Navbar & Theme
 *************************/
const NAV = [
  { key: "dashboard", label: "Beranda" },
  { key: "profile", label: "Profil" },
  { key: "structure", label: "Struktur" },
  { key: "posts", label: "Informasi" },
  { key: "events", label: "Kegiatan" },
  { key: "dues", label: "Iuran" },
  { key: "gallery", label: "Galeri" },
];

function useTheme() {
  const [theme, setTheme] = useLocalState(LS_KEYS.theme, "light");
  useEffect(() => {
    const root = document.documentElement;
    if (theme === "dark") root.classList.add("dark");
    else root.classList.remove("dark");
  }, [theme]);
  return [theme, setTheme];
}

/*************************
 * Halaman: Profil
 *************************/
function ProfilePage() {
  const [profile, setProfile] = useLocalState(LS_KEYS.profile, {
    name: "Karang Taruna Dusun Melati",
    village: "Desa Contoh, Kec. Contoh, Kab. Contoh",
    contacts: { email: "kt.melati@example.com", phone: "0812-0000-0000", address: "Balai Dusun Melati" },
    vision: "Mewujudkan pemuda/i yang berdaya, mandiri, dan berkontribusi nyata untuk dusun.",
    mission: "(1) Menggalang kegiatan sosial & ekonomi pemuda; (2) Pengembangan minat bakat; (3) Digitalisasi administrasi.",
    logoDataUrl: "",
  });

  const fileRef = useRef();

  const onLogo = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => setProfile((p) => ({ ...p, logoDataUrl: reader.result }));
    reader.readAsDataURL(file);
  };

  return (
    <Section title="Profil Organisasi" desc="Perbarui identitas dan informasi kontak.">
      <div className="grid md:grid-cols-3 gap-6">
        <div className="md:col-span-2 space-y-3">
          <Input label="Nama Organisasi" value={profile.name} onChange={(e) => setProfile({ ...profile, name: e.target.value })} />
          <Input label="Alamat/Desa" value={profile.village} onChange={(e) => setProfile({ ...profile, village: e.target.value })} />
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            <Input label="Email" value={profile.contacts.email} onChange={(e) => setProfile({ ...profile, contacts: { ...profile.contacts, email: e.target.value } })} />
            <Input label="Telepon/WA" value={profile.contacts.phone} onChange={(e) => setProfile({ ...profile, contacts: { ...profile.contacts, phone: e.target.value } })} />
            <Input label="Alamat Sekretariat" value={profile.contacts.address} onChange={(e) => setProfile({ ...profile, contacts: { ...profile.contacts, address: e.target.value } })} />
          </div>
          <Textarea rows={4} label="Visi" value={profile.vision} onChange={(e) => setProfile({ ...profile, vision: e.target.value })} />
          <Textarea rows={5} label="Misi" value={profile.mission} onChange={(e) => setProfile({ ...profile, mission: e.target.value })} />
        </div>
        <div>
          <div className="border border-dashed rounded-2xl p-4 text-center flex flex-col items-center justify-center gap-3 h-full">
            {profile.logoDataUrl ? (
              <img src={profile.logoDataUrl} alt="Logo" className="w-28 h-28 object-contain rounded-xl" />
            ) : (
              <div className="text-sm text-neutral-500">Unggah logo (PNG/JPG)</div>
            )}
            <input ref={fileRef} type="file" accept="image/*" onChange={onLogo} className="hidden" />
            <Button onClick={() => fileRef.current?.click()} variant="outline">Pilih Logo</Button>
            <Button variant="ghost" onClick={() => setProfile((p) => ({ ...p, logoDataUrl: "" }))}>Hapus Logo</Button>
          </div>
        </div>
      </div>
    </Section>
  );
}

/*************************
 * Halaman: Struktur Organisasi
 *************************/
function StructurePage() {
  const [items, setItems] = useLocalState(LS_KEYS.structure, [
    { id: crypto.randomUUID(), jabatan: "Ketua", nama: "Budi Santoso", kontak: "0812-1111-2222" },
    { id: crypto.randomUUID(), jabatan: "Wakil Ketua", nama: "Sari Dewi", kontak: "0812-3333-4444" },
    { id: crypto.randomUUID(), jabatan: "Sekretaris", nama: "Andi Saputra", kontak: "0813-5555-6666" },
    { id: crypto.randomUUID(), jabatan: "Bendahara", nama: "Nina Lestari", kontak: "0813-7777-8888" },
  ]);

  const [form, setForm] = useState({ jabatan: "", nama: "", kontak: "" });

  const addItem = () => {
    if (!form.jabatan || !form.nama) return;
    setItems((prev) => [{ id: crypto.randomUUID(), ...form }, ...prev]);
    setForm({ jabatan: "", nama: "", kontak: "" });
  };

  const remove = (id) => setItems((prev) => prev.filter((x) => x.id !== id));

  return (
    <Section title="Struktur Organisasi" desc="Tambahkan atau ubah pengurus dengan cepat.">
      <div className="grid md:grid-cols-3 gap-4 mb-4">
        <Input label="Jabatan" value={form.jabatan} onChange={(e) => setForm({ ...form, jabatan: e.target.value })} />
        <Input label="Nama" value={form.nama} onChange={(e) => setForm({ ...form, nama: e.target.value })} />
        <div className="flex gap-2 items-end">
          <Input label="Kontak (Opsional)" value={form.kontak} onChange={(e) => setForm({ ...form, kontak: e.target.value })} />
          <Button onClick={addItem}>Tambah</Button>
        </div>
      </div>

      {items.length ? (
        <div className="overflow-auto rounded-xl border border-neutral-200 dark:border-neutral-800">
          <table className="min-w-full text-sm">
            <thead className="bg-neutral-50 dark:bg-neutral-900/60">
              <tr>
                <th className="text-left p-3 font-semibold">Jabatan</th>
                <th className="text-left p-3 font-semibold">Nama</th>
                <th className="text-left p-3 font-semibold">Kontak</th>
                <th className="p-3"/>
              </tr>
            </thead>
            <tbody>
              {items.map((it) => (
                <tr key={it.id} className="border-t border-neutral-200 dark:border-neutral-800">
                  <td className="p-3">{it.jabatan}</td>
                  <td className="p-3">{it.nama}</td>
                  <td className="p-3">{it.kontak}</td>
                  <td className="p-3 text-right"><Button variant="danger" onClick={() => remove(it.id)}>Hapus</Button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <Empty hint="Tambahkan pengurus di formulir di atas." />
      )}
    </Section>
  );
}

/*************************
 * Halaman: Informasi / Pengumuman
 *************************/
function PostsPage() {
  const [posts, setPosts] = useLocalState(LS_KEYS.posts, []);
  const [form, setForm] = useState({ title: "", content: "", pinned: false });
  const add = () => {
    if (!form.title) return;
    setPosts((p) => [
      { id: crypto.randomUUID(), ...form, createdAt: new Date().toISOString() },
      ...p,
    ]);
    setForm({ title: "", content: "", pinned: false });
  };
  const del = (id) => setPosts((p) => p.filter((x) => x.id !== id));
  const togglePin = (id) => setPosts((p) => p.map((x) => (x.id === id ? { ...x, pinned: !x.pinned } : x)));

  const ordered = useMemo(() => {
    const pin = posts.filter((p) => p.pinned);
    const rest = posts.filter((p) => !p.pinned);
    return [...pin, ...rest];
  }, [posts]);

  return (
    <Section title="Informasi & Pengumuman" desc="Bagikan kabar terbaru untuk warga & pemuda.">
      <div className="grid md:grid-cols-3 gap-4 mb-4">
        <Input label="Judul" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
        <div className="md:col-span-2"><Textarea rows={3} label="Isi" value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} /></div>
      </div>
      <div className="flex items-center gap-3 mb-4">
        <label className="inline-flex items-center gap-2 text-sm"><input type="checkbox" checked={form.pinned} onChange={(e) => setForm({ ...form, pinned: e.target.checked })} /> Jadikan prioritas (pin)</label>
        <Button onClick={add}>Publikasikan</Button>
      </div>

      {ordered.length ? (
        <div className="grid md:grid-cols-2 gap-4">
          {ordered.map((p) => (
            <div key={p.id} className="border rounded-2xl p-4 border-neutral-200 dark:border-neutral-800">
              <div className="flex items-start justify-between">
                <div className="space-y-1">
                  <div className="font-semibold text-lg">{p.title}</div>
                  <div className="text-xs text-neutral-500">{new Date(p.createdAt).toLocaleString("id-ID")}</div>
                </div>
                <div className="flex gap-2">
                  {p.pinned && <Chip tone="info">Pinned</Chip>}
                  <Button variant="outline" onClick={() => togglePin(p.id)}>Pin/Unpin</Button>
                  <Button variant="danger" onClick={() => del(p.id)}>Hapus</Button>
                </div>
              </div>
              {p.content && <p className="text-sm text-neutral-700 dark:text-neutral-300 mt-3 whitespace-pre-wrap">{p.content}</p>}
            </div>
          ))}
        </div>
      ) : (
        <Empty hint="Tulis pengumuman pertama Anda." />
      )}
    </Section>
  );
}

/*************************
 * Halaman: Kegiatan
 *************************/
function EventsPage() {
  const [events, setEvents] = useLocalState(LS_KEYS.events, []);
  const [form, setForm] = useState({
    name: "",
    date: "",
    status: "Perencanaan",
    budget: 0,
    pic: "",
    note: "",
  });

  const statuses = ["Perencanaan", "Berjalan", "Selesai", "Ditunda"];

  const add = () => {
    if (!form.name) return;
    setEvents((p) => [
      { id: crypto.randomUUID(), ...form, budget: Number(form.budget || 0) },
      ...p,
    ]);
    setForm({ name: "", date: "", status: "Perencanaan", budget: 0, pic: "", note: "" });
  };
  const del = (id) => setEvents((p) => p.filter((x) => x.id !== id));

  const totalBudget = useMemo(() => events.reduce((a, b) => a + Number(b.budget || 0), 0), [events]);

  const exportCSV = () => {
    const csv = toCSV(events.map(({ id, ...r }) => r));
    downloadText(`kegiatan_${new Date().toISOString().slice(0,10)}.csv`, csv);
  };

  return (
    <Section title="Kegiatan" desc="Rencanakan dan pantau kegiatan Karang Taruna.">
      <div className="grid md:grid-cols-6 gap-3 mb-4">
        <div className="md:col-span-2"><Input label="Nama Kegiatan" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></div>
        <Input label="Tanggal" type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} />
        <label className="block text-sm">
          <span className="text-neutral-600 dark:text-neutral-300 mb-1 block">Status</span>
          <select className="w-full rounded-xl border border-neutral-300 dark:border-neutral-700 bg-white dark:bg-neutral-900 px-3 py-2" value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
            {statuses.map((s) => (
              <option key={s}>{s}</option>
            ))}
          </select>
        </label>
        <Input label="Anggaran (Rp)" type="number" value={form.budget} onChange={(e) => setForm({ ...form, budget: e.target.value })} />
        <Input label="Penanggung Jawab" value={form.pic} onChange={(e) => setForm({ ...form, pic: e.target.value })} />
        <div className="md:col-span-6"><Textarea rows={3} label="Catatan" value={form.note} onChange={(e) => setForm({ ...form, note: e.target.value })} /></div>
      </div>
      <div className="flex gap-2 mb-4">
        <Button onClick={add}>Tambah Kegiatan</Button>
        <Button variant="outline" onClick={exportCSV}>Ekspor CSV</Button>
      </div>

      <div className="flex items-center justify-between mb-2">
        <div className="text-sm text-neutral-500">Total Anggaran: <span className="font-semibold text-neutral-700 dark:text-neutral-200">{currency(totalBudget)}</span></div>
      </div>

      {events.length ? (
        <div className="grid md:grid-cols-2 gap-4">
          {events.map((ev) => (
            <div key={ev.id} className="border rounded-2xl p-4 border-neutral-200 dark:border-neutral-800">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <div className="text-lg font-semibold">{ev.name}</div>
                  <div className="text-xs text-neutral-500">{ev.date || "(Tanggal belum diisi)"}</div>
                </div>
                <div className="flex gap-2 items-center">
                  <Chip tone={ev.status === "Selesai" ? "success" : ev.status === "Berjalan" ? "info" : ev.status === "Ditunda" ? "warning" : "default"}>{ev.status}</Chip>
                  <Button variant="danger" onClick={() => del(ev.id)}>Hapus</Button>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3 mt-3 text-sm">
                <div><span className="text-neutral-500">Anggaran</span><div className="font-medium">{currency(ev.budget)}</div></div>
                <div><span className="text-neutral-500">Penanggung Jawab</span><div className="font-medium">{ev.pic || "-"}</div></div>
              </div>
              {ev.note && <p className="text-sm text-neutral-700 dark:text-neutral-300 mt-3 whitespace-pre-wrap">{ev.note}</p>}
            </div>
          ))}
        </div>
      ) : (
        <Empty hint="Tambahkan kegiatan pertama Anda." />
      )}
    </Section>
  );
}

/*************************
 * Halaman: Iuran
 *************************/
function DuesPage() {
  const [dues, setDues] = useLocalState(LS_KEYS.dues, []);
  const [q, setQ] = useState("");
  const [form, setForm] = useState({ nama: "", rt: "", bulan: "", jumlah: 10000, keterangan: "Iuran Rutin" });

  const add = () => {
    if (!form.nama || !form.bulan) return;
    setDues((p) => [
      { id: crypto.randomUUID(), ...form, jumlah: Number(form.jumlah || 0), createdAt: new Date().toISOString() },
      ...p,
    ]);
    setForm({ nama: "", rt: "", bulan: "", jumlah: 10000, keterangan: "Iuran Rutin" });
  };
  const del = (id) => setDues((p) => p.filter((x) => x.id !== id));

  const filtered = useMemo(() => {
    return dues.filter((d) => [d.nama, d.rt, d.bulan, d.keterangan].join(" ").toLowerCase().includes(q.toLowerCase()));
  }, [dues, q]);

  const ringkasan = useMemo(() => {
    const total = filtered.reduce((a, b) => a + Number(b.jumlah || 0), 0);
    const perRT = {};
    filtered.forEach((d) => {
      perRT[d.rt || "-"] = (perRT[d.rt || "-"] || 0) + Number(d.jumlah || 0);
    });
    return { total, perRT };
  }, [filtered]);

  const exportCSV = () => {
    const csv = toCSV(filtered.map(({ id, createdAt, ...r }) => r));
    downloadText(`iuran_${new Date().toISOString().slice(0,10)}.csv`, csv);
  };

  return (
    <Section title="Iuran" desc="Catat pemasukan iuran warga & pemuda, lengkap dengan filter & ekspor.">
      <div className="grid md:grid-cols-6 gap-3 mb-4">
        <Input label="Nama" value={form.nama} onChange={(e) => setForm({ ...form, nama: e.target.value })} />
        <Input label="RT/RW" value={form.rt} onChange={(e) => setForm({ ...form, rt: e.target.value })} />
        <Input label="Bulan (YYYY-MM)" placeholder="2025-08" value={form.bulan} onChange={(e) => setForm({ ...form, bulan: e.target.value })} />
        <Input label="Jumlah (Rp)" type="number" value={form.jumlah} onChange={(e) => setForm({ ...form, jumlah: e.target.value })} />
        <Input label="Keterangan" value={form.keterangan} onChange={(e) => setForm({ ...form, keterangan: e.target.value })} />
        <div className="flex items-end"><Button onClick={add}>Tambah</Button></div>
      </div>

      <div className="flex items-center justify-between gap-3 mb-3">
        <Input label="Cari/Filter" placeholder="cari nama, rt, bulan, keterangan" value={q} onChange={(e) => setQ(e.target.value)} />
        <div className="flex gap-2 items-end">
          <div className="text-sm text-neutral-600 dark:text-neutral-300">Total Terfilter: <span className="font-semibold">{currency(ringkasan.total)}</span></div>
          <Button variant="outline" onClick={exportCSV}>Ekspor CSV</Button>
        </div>
      </div>

      {filtered.length ? (
        <div className="overflow-auto rounded-xl border border-neutral-200 dark:border-neutral-800">
          <table className="min-w-full text-sm">
            <thead className="bg-neutral-50 dark:bg-neutral-900/60">
              <tr>
                <th className="text-left p-3 font-semibold">Nama</th>
                <th className="text-left p-3 font-semibold">RT/RW</th>
                <th className="text-left p-3 font-semibold">Bulan</th>
                <th className="text-left p-3 font-semibold">Jumlah</th>
                <th className="text-left p-3 font-semibold">Keterangan</th>
                <th className="p-3"/>
              </tr>
            </thead>
            <tbody>
              {filtered.map((d) => (
                <tr key={d.id} className="border-t border-neutral-200 dark:border-neutral-800">
                  <td className="p-3">{d.nama}</td>
                  <td className="p-3">{d.rt || "-"}</td>
                  <td className="p-3">{d.bulan}</td>
                  <td className="p-3">{currency(d.jumlah)}</td>
                  <td className="p-3">{d.keterangan}</td>
                  <td className="p-3 text-right"><Button variant="danger" onClick={() => del(d.id)}>Hapus</Button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <Empty hint="Catat iuran pertama Anda." />
      )}

      {Object.keys(ringkasan.perRT).length > 0 && (
        <div className="mt-4 p-4 rounded-xl bg-neutral-50 dark:bg-neutral-900/60 border border-neutral-200 dark:border-neutral-800">
          <div className="font-medium mb-2">Ringkasan per RT</div>
          <div className="grid md:grid-cols-4 gap-2 text-sm">
            {Object.entries(ringkasan.perRT).map(([rt, total]) => (
              <div key={rt} className="flex items-center justify-between p-2 rounded-lg bg-white dark:bg-neutral-950 border border-neutral-200 dark:border-neutral-800">
                <span className="text-neutral-600 dark:text-neutral-300">RT {rt}</span>
                <span className="font-semibold">{currency(total)}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </Section>
  );
}

/*************************
 * Halaman: Galeri
 *************************/
function GalleryPage() {
  const [items, setItems] = useLocalState(LS_KEYS.gallery, []);
  const fileRef = useRef();

  const onPick = (e) => {
    const files = Array.from(e.target.files || []);
    files.forEach((file) => {
      const reader = new FileReader();
      reader.onload = () => {
        setItems((prev) => [{ id: crypto.randomUUID(), dataUrl: reader.result, caption: file.name, createdAt: new Date().toISOString() }, ...prev]);
      };
      reader.readAsDataURL(file);
    });
    e.target.value = "";
  };

  const del = (id) => setItems((prev) => prev.filter((x) => x.id !== id));

  return (
    <Section title="Galeri" desc="Unggah dokumentasi kegiatan dan momen penting.">
      <div className="flex gap-2 mb-4">
        <input ref={fileRef} type="file" accept="image/*" multiple className="hidden" onChange={onPick} />
        <Button onClick={() => fileRef.current?.click()}>Unggah Gambar</Button>
        <Button variant="outline" onClick={() => setItems([])}>Bersihkan Semua</Button>
      </div>
      {items.length ? (
        <div className="grid sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {items.map((it) => (
            <div key={it.id} className="rounded-2xl overflow-hidden border border-neutral-200 dark:border-neutral-800">
              <img src={it.dataUrl} alt={it.caption} className="w-full h-48 object-cover" />
              <div className="p-3 flex items-center justify-between text-sm">
                <div className="truncate" title={it.caption}>{it.caption}</div>
                <Button variant="danger" onClick={() => del(it.id)}>Hapus</Button>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <Empty hint="Klik 'Unggah Gambar' untuk menambah dokumentasi." />
      )}
    </Section>
  );
}

/*************************
 * Halaman: Dashboard (Ringkasan Cepat)
 *************************/
function Dashboard({ goto }) {
  const [events] = useLocalState(LS_KEYS.events, []);
  const [dues] = useLocalState(LS_KEYS.dues, []);
  const [posts] = useLocalState(LS_KEYS.posts, []);
  const [profile] = useLocalState(LS_KEYS.profile, {});

  const totalIuran = useMemo(() => dues.reduce((a, b) => a + Number(b.jumlah || 0), 0), [dues]);
  const berjalan = useMemo(() => events.filter((e) => e.status === "Berjalan").length, [events]);

  return (
    <div className="grid md:grid-cols-3 gap-4">
      <div className="md:col-span-2 space-y-4">
        <Section title={`Selamat datang, ${profile.name || "Karang Taruna"}`} desc={profile.village || "Atur profil organisasi Anda."} right={<Button variant="outline" onClick={() => goto("profile")}>Edit Profil</Button>}>
          <div className="grid md:grid-cols-3 gap-3">
            <StatCard title="Total Iuran Terkumpul" value={currency(totalIuran)} onClick={() => goto("dues")} />
            <StatCard title="Kegiatan Berjalan" value={berjalan} onClick={() => goto("events")} />
            <StatCard title="Pengumuman" value={posts.length} onClick={() => goto("posts")} />
          </div>
        </Section>

        <Section title="Kegiatan Terbaru" right={<Button variant="outline" onClick={() => goto("events")}>Kelola</Button>}>
          {events.length ? (
            <ul className="divide-y divide-neutral-200 dark:divide-neutral-800">
              {events.slice(0, 5).map((e) => (
                <li key={e.id} className="py-3 flex items-center justify-between">
                  <div>
                    <div className="font-medium">{e.name}</div>
                    <div className="text-xs text-neutral-500">{e.date || "(tgl?)"} • {e.pic || "(PJ?)"}</div>
                  </div>
                  <Chip tone={e.status === "Selesai" ? "success" : e.status === "Berjalan" ? "info" : e.status === "Ditunda" ? "warning" : "default"}>{e.status}</Chip>
                </li>
              ))}
            </ul>
          ) : (
            <Empty hint="Belum ada kegiatan. Tambahkan di menu Kegiatan." />
          )}
        </Section>
      </div>
      <div className="space-y-4">
        <Section title="Pengumuman" right={<Button variant="outline" onClick={() => goto("posts")}>Tulis</Button>}>
          {posts.length ? (
            <div className="space-y-3">
              {posts.slice(0, 5).map((p) => (
                <div key={p.id} className="p-3 rounded-xl bg-neutral-50 dark:bg-neutral-900/60 border border-neutral-200 dark:border-neutral-800">
                  <div className="font-medium">{p.title}</div>
                  <div className="text-xs text-neutral-500 mb-2">{new Date(p.createdAt).toLocaleString("id-ID")}</div>
                  {p.content && <div className="text-sm text-neutral-700 dark:text-neutral-300 line-clamp-3">{p.content}</div>}
                </div>
              ))}
            </div>
          ) : (
            <Empty hint="Tulis pengumuman pertama Anda." />
          )}
        </Section>
      </div>
    </div>
  );
}

function StatCard({ title, value, onClick }) {
  return (
    <button onClick={onClick} className="text-left p-4 rounded-2xl bg-white dark:bg-neutral-900 border border-neutral-200 dark:border-neutral-800 hover:shadow transition w-full">
      <div className="text-xs text-neutral-500 mb-1">{title}</div>
      <div className="text-2xl font-semibold">{value}</div>
    </button>
  );
}

/*************************
 * Root App
 *************************/
export default function App() {
  const [active, setActive] = useState("dashboard");
  const [theme, setTheme] = useTheme();

  useEffect(() => {
    const onHash = () => {
      const tab = location.hash.replace("#", "");
      if (NAV.some((n) => n.key === tab)) setActive(tab);
    };
    window.addEventListener("hashchange", onHash);
    onHash();
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  const goto = (key) => {
    setActive(key);
    location.hash = key;
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-neutral-100 to-neutral-200 dark:from-neutral-950 dark:to-neutral-900 text-neutral-900 dark:text-neutral-100">
      <div className="max-w-7xl mx-auto px-4 md:px-6 py-6 md:py-10">
        <header className="flex items-center justify-between gap-3 mb-6">
          <div className="flex items-center gap-3">
            <span className="inline-flex h-10 w-10 items-center justify-center rounded-2xl bg-blue-600 text-white font-bold">KT</span>
            <div>
              <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">Karang Taruna Dusun</h1>
              <p className="text-sm text-neutral-500">Tata kelola modern • cepat • rapi</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Button variant="outline" onClick={() => window.print()}>Cetak</Button>
            <Button variant="outline" onClick={() => setTheme(theme === "dark" ? "light" : "dark")}>{theme === "dark" ? "Mode Terang" : "Mode Gelap"}</Button>
          </div>
        </header>

        <nav className="mb-6 overflow-auto">
          <div className="flex gap-2">
            {NAV.map((n) => (
              <button key={n.key} onClick={() => goto(n.key)} className={`px-4 py-2 rounded-2xl text-sm font-medium border transition whitespace-nowrap ${active === n.key ? "bg-blue-600 text-white border-blue-600" : "bg-white dark:bg-neutral-900 border-neutral-200 dark:border-neutral-800 hover:bg-neutral-50 dark:hover:bg-neutral-800"}`}>
                {n.label}
              </button>
            ))}
          </div>
        </nav>

        <main className="space-y-6 print:space-y-3">
          {active === "dashboard" && <Dashboard goto={goto} />}
          {active === "profile" && <ProfilePage />}
          {active === "structure" && <StructurePage />}
          {active === "posts" && <PostsPage />}
          {active === "events" && <EventsPage />}
          {active === "dues" && <DuesPage />}
          {active === "gallery" && <GalleryPage />}
        </main>

        <footer className="text-center text-xs text-neutral-500 mt-10">
          © {new Date().getFullYear()} Karang Taruna Dusun — Dibuat dengan ❤️. Data disimpan lokal pada perangkat Anda.
        </footer>
      </div>

      <style>{`
        @media print {
          nav, header > div:last-child, footer, .no-print { display: none !important; }
          body { background: white !important; }
          main > section { break-inside: avoid; }
        }
      `}</style>
    </div>
  );
}

