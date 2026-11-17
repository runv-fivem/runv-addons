const post = (name, data) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {}),
});

Vue.createApp({
    data() {
        return { open: false, speaker: '', line: '', reply: '' };
    },
    methods: {
        next() { post('next'); },
    },
    mounted() {
        window.addEventListener('message', (e) => {
            const d = e.data;
            if (d.action === 'line') {
                this.speaker = d.speaker;
                this.line = d.line;
                this.reply = d.reply;
                this.open = true;
            } else if (d.action === 'close') {
                this.open = false;
            }
        });
        window.addEventListener('keydown', (e) => {
            if (this.open && (e.key === 'e' || e.key === 'E')) this.next();
        });
    },
}).mount('#app');
