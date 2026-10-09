import {defineConfig} from 'vite';
import tailwind from '@tailwindcss/postcss';
import {fileURLToPath} from 'node:url';
export default defineConfig({resolve:{alias:{'@':fileURLToPath(new URL('.',import.meta.url))}},esbuild:{jsx:'automatic'},css:{postcss:{plugins:[tailwind()]}},build:{lib:{entry:'src/main.tsx',name:'Minuto',formats:['iife'],fileName:()=> 'app.js',cssFileName:'style'},outDir:'web',emptyOutDir:true},define:{'process.env.NODE_ENV':JSON.stringify('production')}});
