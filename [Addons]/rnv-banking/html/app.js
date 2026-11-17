const post = (name, data) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {}),
});

const money = (n) => '$' + String(Math.floor(n)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');

Vue.createApp({
    data() {
        return { kind: null, fee: '', balance: 0, balanceText: '', amount: '' };
    },
    computed: {
        title() { return this.kind === 'open' ? 'OPENING A BANK ACCOUNT' : 'WITHDRAW CASH'; },
        value() { return parseInt(this.amount, 10) || 0; },
        canConfirm() { return this.kind === 'open' || (this.value > 0 && this.value <= this.balance); },
        okText() { return this.kind === 'open' ? 'OPEN ' + this.fee : 'WITHDRAW ' + money(this.value); },
    },
    methods: {
        clean() { this.amount = this.amount.replace(/\D/g, ''); },
        cancel() { this.kind = null; post('cancel'); },
        confirm() {
            if (!this.canConfirm) return;
            const amount = this.value;
            this.kind = null;
            post('confirm', { amount });
        },
    },
    mounted() {
        window.addEventListener('message', (e) => {
            const d = e.data;
            if (d.action === 'open') {
                this.fee = d.fee;
                this.kind = 'open';
            } else if (d.action === 'withdraw') {
                this.balance = d.balance;
                this.balanceText = d.balanceText;
                this.amount = '';
                this.kind = 'withdraw';
                this.$nextTick(() => this.$refs.amount && this.$refs.amount.focus());
            } else if (d.action === 'close') {
                this.kind = null;
            }
        });
        window.addEventListener('keydown', (e) => {
            if (!this.kind) return;
            if (e.key === 'Escape') this.cancel();
            else if (e.key === 'Enter') { e.preventDefault(); this.confirm(); }
        });
    },
}).mount('#app');
