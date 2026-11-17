FROM node@sha256:c3324aa3efea082c8d294a93b97ba82adc5498a202bd48802f5a8af152e7dd9e AS build
WORKDIR /app
COPY site/package.json site/astro.config.mjs site/tsconfig.json ./site/
COPY site/src ./site/src
COPY site/public ./site/public
RUN cd site && npm install --no-audit --no-fund && npm run build

FROM nginx@sha256:07019dae7c324421c9193722d274299d8dc352cf108c17d3e904e051a2b8dd9e
COPY --from=build /app/site/dist /usr/share/nginx/html
