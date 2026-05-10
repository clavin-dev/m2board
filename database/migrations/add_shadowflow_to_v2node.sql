-- ShadowFlow 集成到 V2node: 给 v2_server_v2node 表添加 shadowflow 专用字段
-- 执行方式: mysql -u root -p v2board < database/migrations/add_shadowflow_to_v2node.sql

-- 伪装模式: web_browsing, live_stream, file_download, video_call
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `camouflage` varchar(32) DEFAULT NULL COMMENT 'ShadowFlow伪装模式: web_browsing, live_stream, file_download, video_call'
    AFTER `padding_scheme`;

-- 流量整形配置 JSON: {"padding":{"min":64,"max":256},"fragment":{"min_size":100,"max_size":500},"split":true}
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `shaping_settings` text DEFAULT NULL COMMENT 'ShadowFlow流量整形JSON配置'
    AFTER `camouflage`;
