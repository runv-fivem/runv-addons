const post = (name, data) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {}),
});

// The map is the real world under the game's aerial camera (client/main.lua). This page only draws the
// pieces (diamonds, popup, cards, back key) where the Lua side says the places are, and sends drag / wheel / click
let drag = null, lastHover = 0;

const app = Vue.createApp({
    data() {
        return {
            open: false, places: [], sel: null, screen: {}, busy: false,
            icons: {
                home: 'M12 3l9 8h-3v9h-5v-6h-2v6H6v-9H3z',
                person: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm-8 9c0-4 4-6 8-6s8 2 8 6z',
                chart: 'M5 19V11h3v8H5zm5.5 0V5h3v14h-3zM16 19v-6h3v6h-3z',
            },
        };
    },
    computed: {
        place() { return this.places.find((p) => p.id === this.sel); },
        cards() { return this.places.filter((p) => p.card); },
        popStyle() {
            // left of the selected zone, vertically on its diamond
            const m = this.screen[this.sel] || { y: 0.5, left: 0.5 };
            const rem = innerHeight / 108;
            const left = Math.min(innerWidth - 55.4 * rem, Math.max(3.6 * rem, m.left * innerWidth - 53.8 * rem));
            const top = Math.min(innerHeight - 30 * rem, Math.max(30 * rem, m.y * innerHeight));
            return { left: left + 'px', top: top + 'px', transform: 'translateY(-50%)' };
        },
    },
    methods: {
        markerStyle(id) {
            const m = this.screen[id];
            if (!m || !m.on) return { display: 'none' };
            return { left: m.x * 100 + '%', top: m.y * 100 + '%' };
        },
        select(id) {
            post('select', { id });
        },
        down(e) {
            drag = { x: e.clientX, y: e.clientY, lx: e.clientX, ly: e.clientY, moved: false };
        },
        move(e) {
            if (!drag) {
                // hover: the zone under the mouse gets a stronger roof (asked at most every 60 ms)
                if (this.open && Date.now() - lastHover > 60) {
                    lastHover = Date.now();
                    post('hover', { u: e.clientX / innerWidth, v: e.clientY / innerHeight });
                }
                return;
            }
            if (!drag.moved && Math.hypot(e.clientX - drag.x, e.clientY - drag.y) < 5) return;
            drag.moved = true;
            post('pan', { dx: e.clientX - drag.lx, dy: e.clientY - drag.ly, h: innerHeight });
            drag.lx = e.clientX;
            drag.ly = e.clientY;
        },
        up(e) {
            if (drag && !drag.moved) post('pick', { u: e.clientX / innerWidth, v: e.clientY / innerHeight });
            drag = null;
        },
        travel(id) {
            if (this.busy) return;
            this.busy = true;
            post('travel', { id });
        },
        back() {
            if (this.busy) return;
            this.busy = true;
            post('back');
        },
    },
    mounted() {
        window.addEventListener('message', (e) => {
            const d = e.data;
            if (d.action === 'open') {
                this.places = d.places;
                this.sel = null;
                this.busy = false;
                this.open = true;
            } else if (d.action === 'frame') {
                this.screen = d.screen;
            } else if (d.action === 'select') {
                this.sel = d.id || null;
            } else if (d.action === 'close') {
                this.open = false;
                this.sel = null;
            }
        });
        window.addEventListener('keydown', (e) => {
            if (!this.open) return;
            if (e.key === 'Escape') {
                if (this.sel) this.select(null); else this.back();
            } else if (e.key === 'Enter' && this.place && this.place.travel) {
                this.travel(this.place.id);
            }
        });
        // listeners on window: setPointerCapture breaks drag in the game's browser
        window.addEventListener('pointermove', (e) => this.move(e));
        window.addEventListener('pointerup', (e) => this.up(e));
        window.addEventListener('wheel', (e) => { if (this.open) post('zoom', { dir: e.deltaY > 0 ? 1 : -1 }); });
    },
}).mount('#app');
