// @ts-check
import { themes as prismThemes } from 'prism-react-renderer';

/** @type {import('@docusaurus/types').Config} */
const config = {
    title: 'Docs',
    tagline: 'User documentation for HAI Protocol',
    favicon: 'img/favicon.ico',

    future: {
        v4: true,
    },

    url: 'https://letsgethai.com',
    baseUrl: '/',
    organizationName: 'hai-on-op',
    projectName: 'core',

    onBrokenLinks: 'throw',
    onBrokenMarkdownLinks: 'warn',

    i18n: {
        defaultLocale: 'en',
        locales: ['en'],
    },

    presets: [
        [
            'classic',
            /** @type {import('@docusaurus/preset-classic').Options} */
            ({
                docs: {
                    sidebarPath: './sidebars.js',
                    editUrl: 'https://github.com/hai-on-op/core/tree/main/user-docs/',
                    routeBasePath: '/', // This makes docs the homepage
                },
                blog: false, // Blog disabled
                theme: {
                    customCss: './src/css/custom.css',
                },
            }),
        ],
    ],

    themeConfig:
        /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
        ({
            image: 'img/hai-social-card.jpg',
            navbar: {
                title: 'User Docs',
                logo: {
                    alt: 'HAI Logo',
                    src: 'https://www.letsgethai.com/assets/logo-0100ea7f.png',
                },
                items: [
                    {
                        href: 'https://www.letsgethai.com',
                        label: 'HAI Home',
                        position: 'right',
                    },
                ],
            },
            footer: {
                style: 'dark',
                links: [
                    {
                        title: 'Docs',
                        items: [
                            {
                                label: 'Intro',
                                to: '/intro',
                            },
                            {
                                label: 'Getting Started',
                                to: '/getting-started',
                            },
                        ],
                    },
                    {
                        title: 'Community',
                        items: [
                            {
                                label: 'Twitter',
                                href: 'https://x.com/letsgethai',
                            },
                            {
                                label: 'Discord',
                                href: 'https://discord.gg/letsgethai',
                            },
                        ],
                    },
                    {
                        title: 'More',
                        items: [
                            {
                                label: 'HAI Main Site',
                                href: 'https://www.letsgethai.com',
                            },
                        ],
                    },
                ],
                copyright: `© ${new Date().getFullYear()} HAI Protocol`,
            },
            prism: {
                theme: prismThemes.github,
                darkTheme: prismThemes.dracula,
            },
        }),
};

export default config;

