const post = (name, data) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {}),
});

Vue.createApp({
    data() {
        return { open: false, debt: 0, balance: 0 };
    },
    methods: {
        money(n) { return '$' + String(Math.floor(n)).replace(/\B(?=(\d{3})+(?!\d))/g, '.'); },
        cancel() { this.open = false; post('cancel'); },
        confirm() {
            if (this.balance < this.debt) return;
            this.open = false;
            post('confirm');
        },
    },
    mounted() {
        window.addEventListener('message', (e) => {
            const d = e.data;
            if (d.action === 'debt') {
                this.debt = d.debt;
                this.balance = d.balance;
                this.open = true;
            } else if (d.action === 'close') {
                this.open = false;
            }
        });
        window.addEventListener('keydown', (e) => {
            if (!this.open) return;
            if (e.key === 'Escape') this.cancel();
            else if (e.key === 'Enter') this.confirm();
        });
    },
}).mount('#app');
