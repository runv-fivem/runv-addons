const post = (name, data) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data === undefined ? {} : data),
}).then((r) => r.json()).catch(() => null);

const ERRORS = {
    name: 'Name 3-16 letters, tag 2-4 letters', taken: 'Name or tag already taken', funds: 'Not enough bank balance', account: 'Open a bank account first',
    full: 'The clan is full', requested: 'Request sent', leader: 'Give the Leader rank to someone else first', offline: 'No online player with that UID',
    member: 'That player is already in a clan',
};

Vue.createApp({
    data() {
        return {
            open: false, data: null, screen: 'intro', tab: 'clan', page: 1, error: '',
            form: { emblem: 1, name: '', tag: '', language: 'English', entry: 'open', description: '' },
            query: '', openOnly: false, langFilter: 'Any Language', results: [], picked: null,
            mview: 'list', menuFor: null, inviteOpen: false, inviteId: '', editOpen: false, edit: {}, taxIn: 0,
            cardPath: 'M2 6h20v12H2V6zm0 3v2h20V9H2zm3 5v2h6v-2H5z',
        };
    },
    computed: {
        pages() { return Math.max(1, Math.ceil(this.data.emblems / 12)); },
        emblemPage() { const s = (this.page - 1) * 12; return Array.from({ length: Math.min(12, this.data.emblems - s) }, (_, i) => s + i + 1); },
        canCreate() { return this.form.name.trim().length >= 3 && this.form.tag.trim().length >= 2 && this.data.bank >= this.data.fee; },
    },
    methods: {
        fmt(n) { return Math.floor(n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.'); },
        money(n) { return this.fmt(n); },
        clock(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0'); },
        hhmm(t) { const d = new Date(t * 1000); return String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0'); },
        tileStyle(n) {
            const i = (n - 1) % 12, xs = [18.6, 33.5, 48.2], ys = [26.3, 41, 55.9, 70.7];
            return { left: xs[i % 3] + 'rem', top: ys[Math.floor(i / 3)] + 'rem' };
        },
        apply(v) {
            if (!v) return;
            this.data = v;
            this.screen = v.mode === 'clan' ? 'clan' : (this.screen === 'clan' ? 'intro' : this.screen);
            this.taxIn = v.taxIn || 0;
        },
        showError(why) { this.error = ERRORS[why] || ''; setTimeout(() => { this.error = ''; }, 3500); },
        async goSearch() { this.screen = 'search'; this.picked = null; await this.search(); },
        async search() { this.results = (await post('search', { query: this.query, openOnly: this.openOnly, language: this.langFilter })) || []; },
        async create() {
            if (!this.canCreate) return;
            const r = await post('create', this.form);
            if (r && r.view) this.apply(r.view); else this.showError(r && r.why);
        },
        async join() {
            if (!this.picked) return;
            const r = await post('join', { id: this.picked.id });
            if (r && r.view) this.apply(r.view); else this.showError(r && r.why);
        },
        async act(name, a, b) {
            this.menuFor = null;
            const r = await post('action', { name, a, b });
            if (r && r.view) this.apply(r.view); else this.showError(r && r.why);
            if (r && r.view && r.view.mode === 'intro') this.screen = 'intro';
        },
        async invite() {
            const r = await post('action', { name: 'invite', a: this.inviteId });
            this.showError(r && r.ok ? '' : (r && r.why) || 'offline');
            if (r && r.ok) { this.inviteOpen = false; this.inviteId = ''; }
        },
        openEdit() {
            if (!this.data.me || !this.data.me.manage) return;
            this.edit = { announcement: this.data.clan.announcement, description: this.data.clan.description, entry: this.data.clan.entry };
            this.editOpen = true;
        },
        async saveEdit() { this.editOpen = false; await this.act('edit', this.edit); },
        back() {
            if (this.editOpen) { this.editOpen = false; return; }
            if (this.screen === 'create' || this.screen === 'search') { this.screen = 'intro'; return; }
            this.close();
        },
        close() { this.open = false; this.editOpen = false; post('close'); },
    },
    mounted() {
        window.addEventListener('message', (e) => {
            const d = e.data;
            if (d.action === 'open') { this.open = true; this.tab = 'clan'; this.screen = d.view.mode === 'clan' ? 'clan' : 'intro'; this.apply(d.view); }
            else if (d.action === 'update') this.apply(d.view);
            else if (d.action === 'close') this.open = false;
            else if (d.action === 'tab') { if (d.tab === 'intro' || d.tab === 'search') this.screen = d.tab; else this.tab = d.tab; }
        });
        window.addEventListener('keydown', (e) => {
            if (!this.open) return;
            const typing = ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName);
            if (e.key === 'Escape') this.back();
            else if (!typing && (e.key === 'f' || e.key === 'F') && this.screen === 'clan') this.openEdit();
            else if (!typing && (e.key === 'e' || e.key === 'E') && this.screen === 'search') this.join();
        });
        setInterval(() => { if (this.taxIn > 0) this.taxIn -= 1; }, 1000);
    },
}).mount('#app');
