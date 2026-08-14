import { defineConfig } from 'vitepress'

// CourierSim《快递王国》设计文档站配置（自包含于 docs/ 目录）。
export default defineConfig({
  title: 'CourierSim · 快递王国',
  description:
    '基于 Godot 4 的 2D 像素卡通任天堂风快递公司模拟经营游戏 · 完整开发规划与设计文档',
  lang: 'zh-CN',

  // 部署到 GitHub Pages 的 <repo> 子路径时，取消下一行注释并改为实际仓库名：
  // base: '/CourierSim/',

  markdown: {
    // 关闭原生 HTML 透传与 markdown-it-attrs 属性语法：
    // 文档中大量出现 { ... }（JSON/配置示例），attrs 插件会误判导致编译报错。
    html: false,
    attrs: { disable: true },
  },

  themeConfig: {
    nav: [
      { text: '概览', link: '/overview/vision' },
      { text: '核心玩法', link: '/gameplay/' },
      { text: '地图与区域', link: '/map/' },
      { text: 'UI / UX', link: '/ui/ui-design' },
      { text: '技术架构', link: '/architecture/' },
      { text: '素材清单', link: '/assets/' },
      { text: '开发计划', link: '/development/roadmap' },
    ],

    sidebar: {
      '/overview/': [
        {
          text: '项目概览',
          items: [
            { text: '愿景与设计支柱', link: '/overview/vision' },
            { text: '参考项目：TransRoute', link: '/overview/reference' },
            { text: '核心循环', link: '/overview/core-loop' },
          ],
        },
      ],
      '/gameplay/': [
        {
          text: '核心玩法',
          items: [
            { text: '玩法总览', link: '/gameplay/' },
            { text: '游戏模式', link: '/gameplay/modes' },
            { text: '时间系统', link: '/gameplay/time' },
            { text: '生涯评级与存档槽位', link: '/gameplay/progression' },
            { text: '生涯模式剧情引导', link: '/gameplay/career-tutorial' },
            { text: '车辆系统', link: '/gameplay/vehicle' },
            { text: '中转仓库', link: '/gameplay/hub' },
            { text: '站点建设', link: '/gameplay/station' },
            { text: '市场宣传与推广', link: '/gameplay/marketing' },
            { text: '订单与货流', link: '/gameplay/order' },
            { text: '经济与财务', link: '/gameplay/finance' },
            { text: '员工与人力', link: '/gameplay/staff' },
            { text: '科技研发', link: '/gameplay/tech' },
            { text: '突发事件与竞争', link: '/gameplay/events' },
          ],
        },
      ],
      '/map/': [
        {
          text: '地图与区域',
          items: [
            { text: '地图系统总览', link: '/map/' },
            { text: '真实地图渲染', link: '/map/real-map' },
            { text: '地图数据获取', link: '/map/data-acquisition' },
            { text: '坐标与投影转换', link: '/map/coordinate' },
            { text: '区域切换机制', link: '/map/region-switching' },
            { text: '距离与用时计算', link: '/map/distance-time' },
            { text: '区域内容规划', link: '/map/region-content' },
          ],
        },
      ],
      '/ui/': [
        {
          text: 'UI / UX',
          items: [
            { text: '设计规范', link: '/ui/ui-design' },
            { text: '插件与资源库', link: '/ui/plugins' },
          ],
        },
      ],
      '/architecture/': [
        {
          text: '技术架构',
          items: [
            { text: '架构总览', link: '/architecture/' },
            { text: '项目目录结构', link: '/architecture/structure' },
            { text: '插件与第三方库', link: '/architecture/plugins' },
            { text: '模块实现要点', link: '/architecture/modules' },
            { text: '数据管线', link: '/architecture/data-pipeline' },
            { text: '存档系统', link: '/architecture/save-system' },
            { text: '性能优化', link: '/architecture/performance' },
            { text: 'Internationalization (i18n)', link: '/architecture/i18n' },
          ],
        },
      ],
      '/assets/': [
        {
          text: '素材清单',
          items: [
            { text: '素材总览与美术风格', link: '/assets/' },
            { text: '精灵图清单', link: '/assets/sprites' },
            { text: '音效与音乐清单', link: '/assets/audio' },
            { text: 'UI 素材清单', link: '/assets/ui' },
            { text: '地图资源清单', link: '/assets/map-assets' },
          ],
        },
      ],
      '/development/': [
        {
          text: '开发计划',
          items: [
            { text: '阶段划分与里程碑', link: '/development/roadmap' },
            { text: '数据管理与配置', link: '/development/data-management' },
            { text: '测试与发布', link: '/development/qa' },
            { text: '开源与许可（AGPL）', link: '/development/license' },
          ],
        },
      ],
    },

    search: { provider: 'local' },
    docFooter: { prev: true, next: true },
    outline: { level: [2, 3] },
    lastUpdated: true,
    socialLinks: [{ icon: 'github', link: 'https://github.com/' }],

    footer: {
      message: 'CourierSim · 基于 Godot 4 的快递公司模拟经营游戏',
      copyright: 'AGPL-3.0 开源 · 文档随源码维护',
    },
  },
})
