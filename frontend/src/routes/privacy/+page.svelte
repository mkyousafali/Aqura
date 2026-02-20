<script lang="ts">
    const companyName = "Urban Aqura";
    const appName = "Aqura";
    const website = "https://urbanksa.app";
    const email = "info@urbanaqura.com";
    const lastUpdated = "February 20, 2026";
</script>

<svelte:head>
    <title>Privacy Policy - {appName}</title>
</svelte:head>

<div class="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
    <div class="max-w-3xl mx-auto bg-white rounded-2xl shadow-sm p-8 sm:p-12">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">Privacy Policy</h1>
        <p class="text-sm text-gray-500 mb-8">Last updated: {lastUpdated}</p>

        <div class="space-y-6 text-gray-700 leading-relaxed">
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">1. Introduction</h2>
                <p>{companyName} ("we", "our", or "us") operates the {appName} management system and related services available at <a href={website} class="text-blue-600 underline">{website}</a>. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our application and services, including our WhatsApp Business integration.</p>
            </section>

            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">2. Information We Collect</h2>
                <p class="mb-2">We may collect the following types of information:</p>
                <ul class="list-disc pl-6 space-y-1">
                    <li><strong>Account Information:</strong> Name, email address, phone number, and role when you register or are added as a user.</li>
                    <li><strong>Business Data:</strong> Inventory, sales, financial, and operational data entered into the system by authorized users.</li>
                    <li><strong>WhatsApp Messaging Data:</strong> Phone numbers, message content, delivery status, and conversation history when you interact with our WhatsApp Business integration.</li>
                    <li><strong>Usage Data:</strong> Login activity, feature usage, device information, and IP addresses for security and analytics purposes.</li>
                    <li><strong>Biometric Data:</strong> Fingerprint records for attendance tracking, processed and stored securely.</li>
                </ul>
            </section>

            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">3. How We Use Your Information</h2>
                <ul class="list-disc pl-6 space-y-1">
                    <li>To provide, operate, and maintain our services</li>
                    <li>To process transactions and manage business operations</li>
                    <li>To send transactional messages via WhatsApp (access codes, order updates, notifications)</li>
                    <li>To provide customer support through WhatsApp Business messaging</li>
                    <li>To improve and personalize your experience</li>
                    <li>To ensure security and prevent unauthorized access</li>
                    <li>To comply with legal obligations</li>
                </ul>
            </section>

            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">4. WhatsApp Business Integration</h2>
                <p>We use the Meta WhatsApp Business API to communicate with customers. When you message our WhatsApp Business number:</p>
                <ul class="list-disc pl-6 space-y-1">
                    <li>Your phone number and message content are processed to respond to your inquiries</li>
                    <li>Messages may be handled by automated bots or human agents</li>
                    <li>Conversation history is stored securely for service quality and continuity</li>
                    <li>We do not sell or share your WhatsApp data with third parties for marketing purposes</li>
                </ul>
            </section>

            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">5. Data Storage and Security</h2>
                <p>Your data is stored on secure servers with encryption at rest and in transit. We implement industry-standard security measures including access controls, monitoring, and regular security assessments to protect your information.</p>
            </section>

            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">6. Data Sharing</h2>
                <p>We do not sell your personal information. We may share data only:</p>
                <ul class="list-disc pl-6 space-y-1">
                    <li>With service providers who assist in operating our platform (hosting, messaging APIs)</li>
                    <li>When required by law or legal process</li>
                    <li>To protect our rights, privacy, safety, or property</li>
                    <li>With your consent</li>
                </ul>
            </section>

            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">7. Data Retention</h2>
                <p>We retain your data for as long as your account is active or as needed to provide services. WhatsApp conversation data is retained for business record-keeping purposes. You may request deletion of your data by contacting us.</p>
            </section>

            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">8. Your Rights</h2>
                <p>You have the right to:</p>
                <ul class="list-disc pl-6 space-y-1">
                    <li>Access your personal data</li>
                    <li>Request correction of inaccurate data</li>
                    <li>Request deletion of your data</li>
                    <li>Opt out of marketing communications</li>
                    <li>Withdraw consent for data processing</li>
                </ul>
            </section>

            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">9. Contact Us</h2>
                <p>If you have questions about this Privacy Policy or our data practices, please contact us at:</p>
                <p class="mt-2"><strong>{companyName}</strong><br>Email: <a href="mailto:{email}" class="text-blue-600 underline">{email}</a></p>
            </section>
        </div>

        <div class="mt-10 pt-6 border-t border-gray-200 text-center">
            <a href="/" class="text-blue-600 hover:underline text-sm">← Back to {appName}</a>
        </div>
    </div>
</div>
