-- ShadowFlow v2 字段: 画像选择、路径池、连接生命周期、速率、SNI
-- 执行方式: mysql -u root -p v2board < database/migrations/add_shadowflow_v2_fields.sql
-- 注意: 如果列已存在会报错，可忽略

-- 流量画像: chrome_h2, safari, firefox, apple_music, douyin, bilibili, taobao, icloud_sync, tencent_video
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `traffic_profile` varchar(32) DEFAULT NULL COMMENT '流量画像名称'
    AFTER `shaping_settings`;

-- 路径池: 每行一个路径模板
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `path_pool` text DEFAULT NULL COMMENT '路径池(每行一个)'
    AFTER `traffic_profile`;

-- 连接最大生命周期(秒), 0=不限制
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `conn_max_lifetime` int(11) DEFAULT 0 COMMENT '连接最大存活时间(秒)'
    AFTER `path_pool`;

-- 上行/下行速率限制 (Mbps)
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `upload_rate` decimal(10,2) DEFAULT 0 COMMENT '上行速率限制(Mbps)'
    AFTER `conn_max_lifetime`;

ALTER TABLE `v2_server_v2node`
    ADD COLUMN `download_rate` decimal(10,2) DEFAULT 0 COMMENT '下行速率限制(Mbps)'
    AFTER `upload_rate`;

-- 上行/下行域名池
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `upload_host` text DEFAULT NULL COMMENT '上行域名池(每行一个)'
    AFTER `download_rate`;

ALTER TABLE `v2_server_v2node`
    ADD COLUMN `download_host` text DEFAULT NULL COMMENT '下行域名池(每行一个)'
    AFTER `upload_host`;

-- SNI 模式和池
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `sni_mode` varchar(16) DEFAULT 'random' COMMENT 'SNI模式: random/fixed'
    AFTER `download_host`;

ALTER TABLE `v2_server_v2node`
    ADD COLUMN `sni_pool` text DEFAULT NULL COMMENT 'SNI域名池(每行一个)'
    AFTER `sni_mode`;

-- 动态切换间隔
ALTER TABLE `v2_server_v2node`
    ADD COLUMN `switch_interval_min` int(11) DEFAULT 30 COMMENT '画像切换最小间隔(秒)'
    AFTER `sni_pool`;

ALTER TABLE `v2_server_v2node`
    ADD COLUMN `switch_interval_max` int(11) DEFAULT 120 COMMENT '画像切换最大间隔(秒)'
    AFTER `switch_interval_min`;
