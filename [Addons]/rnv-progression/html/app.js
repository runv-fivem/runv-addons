const post = (name, data) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {}),
}).then((r) => r.json());

const row = () => 108 * window.innerHeight / 1080; // one list row in px (10.8rem)

Vue.createApp({
    data() {
        return { open: false, d: { tattoos: [] }, selected: null, card: null, busy: false };
    },
    computed: {
        reversed() { return this.d.tattoos.slice().reverse(); }, // highest threshold on top
        ownedCount() { return this.d.tattoos.filter((t) => t.owned).length; },
        current() { return this.d.tattoos.find((t) => t.id === this.selected); },
        canClaim() { return this.current && this.d.atArtist && !this.current.owned && this.d.authority >= this.current.threshold; },
        nextLocked() { return this.d.tattoos.find((t) => !t.owned); },
        // green bar from the bottom row up to the current Authority (between two thresholds)
        barFill() {
            const list = this.d.tattoos;
            let reached = -1;
            for (let i = 0; i < list.length; i++) if (this.d.authority >= list[i].threshold) reached = i;
            if (reached < 0) return 0;
            const ROW = row();
            let fill = (reached + 0.5) * ROW;
            const next = list[reached + 1];
            if (next) {
                const part = (this.d.authority - list[reached].threshold) / (next.threshold - list[reached].threshold);
                fill += Math.min(part, 1) * ROW;
            } else {
                fill += 0.5 * ROW;
            }
            return fill;
        },
    },
    methods: {
        select(id) {
            this.selected = id;
            post('preview', { id });
        },
        async claim() {
            if (!this.canClaim || this.busy) return;
            this.busy = true;
            const t = this.current;
            const res = await post('claim', { id: t.id });
            this.busy = false;
            if (res.ok) {
                t.owned = true;
                this.card = t;
            }
        },
        close() {
            if (this.card) { this.card = null; return; }
            post('close');
        },
        scrollToBottom() {
            this.$nextTick(() => {
                const el = this.$refs.list;
                if (!el) return;
                el.querySelector('.bar').style.setProperty('--h', `${this.d.tattoos.length * row()}px`);
                el.scrollTop = el.scrollHeight;
            });
        },
    },
    mounted() {
        window.addEventListener('message', (e) => {
            const m = e.data;
            if (m.action === 'open') {
                this.d = m.data;
                this.card = null;
                this.open = true;
                const first = this.d.tattoos.find((t) => !t.owned) || this.d.tattoos[0];
                this.selected = first ? first.id : null;
                if (first) post('preview', { id: first.id });
                this.scrollToBottom();
            } else if (m.action === 'update') {
                this.d.authority = m.data.authority;
                for (const t of m.data.tattoos) {
                    const mine = this.d.tattoos.find((x) => x.id === t.id);
                    if (mine) mine.owned = t.owned;
                }
            } else if (m.action === 'close') {
                this.open = false;
            }
        });
        window.addEventListener('keydown', (e) => {
            if (!this.open) return;
            if (e.key === 'Escape') this.close();
            else if (e.key === 'e' || e.key === 'E') {
                if (this.card) this.card = null;
                else this.claim();
            }
        });
    },
}).mount('#app');
