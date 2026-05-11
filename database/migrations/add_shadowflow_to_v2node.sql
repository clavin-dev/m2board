-- ShadowFlow 集成到 V2node: 给 v2_server_v2node 表添加 shadowflow 专用字段
-- 执行方式: mysql -u root -p v2board < database/migrations/add_shadowflow_to_v2node.sql

-- 伪装模式: random, dynamic
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `camouflage` varchar(32) DEFAULT NULL COMMENT 'ShadowFlow伪装模式: random, dynamic'
    AFTER `padding_scheme`;

-- 流量整形配置 JSON
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `shaping_settings` text DEFAULT NULL COMMENT 'ShadowFlow流量整形JSON配置'
    AFTER `camouflage`;

-- 传输层类型: tcp, ws, grpc, reality
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `transport_type` varchar(16) DEFAULT 'tcp' COMMENT 'ShadowFlow传输类型: tcp, ws, grpc, reality'
    AFTER `shaping_settings`;

-- 传输层路径 (ws/grpc 专用)
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `transport_path` varchar(255) DEFAULT '/ws' COMMENT 'ShadowFlow传输路径(ws/grpc)'
    AFTER `transport_type`;

-- 传输层 Host (ws/grpc CDN 穿透用)
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `transport_host` varchar(255) DEFAULT NULL COMMENT 'ShadowFlow传输Host(CDN域名)'
    AFTER `transport_path`;
