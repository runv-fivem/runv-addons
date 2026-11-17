const post = (name, data) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {}),
});

Vue.createApp({
    data() {
        return { open: false, name: '', has: 0, image: '' };
    },
    methods: {
        cancel() { this.open = false; post('cancel'); },
        rent() {
            if (this.has < 1) return;
            this.open = false;
            post('rent');
        },
    },
    mounted() {
        window.addEventListener('message', (e) => {
            const d = e.data;
            if (d.action === 'rent') {
                this.name = d.name;
                this.has = d.has;
                this.image = d.image;
                this.open = true;
            } else if (d.action === 'close') {
                this.open = false;
            }
        });
        window.addEventListener('keydown', (e) => {
            if (!this.open) return;
            if (e.key === 'Escape') this.cancel();
            else if (e.key === 'Enter') this.rent();
        });
    },
}).mount('#app');
