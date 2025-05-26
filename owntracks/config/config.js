window.owntracks = window.owntracks || {};
window.owntracks.config = {
    // 地圖設定
    map: {
        // 預設地圖中心點 (經緯度)
        center: [25.0330, 121.5654],  // 台北市座標，請調整為你的位置
        zoom: 10,                     // 預設縮放級別
        
        // 地圖圖層設定
        layers: [
            {
                name: 'OpenStreetMap',
                url: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                attribution: '© OpenStreetMap contributors',
                default: true
            },
            {
                name: 'Satellite',
                url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                attribution: 'Esri, DigitalGlobe, GeoEye, Earthstar Geographics, CNES/Airbus DS, USDA, USGS, AeroGRID, IGN, and the GIS User Community'
            }
        ]
    },
    
    // 使用者介面設定
    ui: {
        // 預設顯示的時間範圍 (小時)
        defaultHours: 24,
        
        // 是否顯示所有裝置
        showAllDevices: true,
        
        // 軌跡線條設定
        track: {
            color: '#3388ff',
            weight: 3,
            opacity: 0.8
        },
        
        // 標記點設定
        marker: {
            color: '#ff3333',
            size: 8
        }
    },
    
    // 認證設定 (如果 recorder 有啟用認證)
    auth: {
        enabled: false,
        // 如果啟用認證，請設定以下項目
        // username: 'your-username',
        // password: 'your-password'
    },
    
    // 自動重新整理設定
    refresh: {
        enabled: true,
        interval: 30000  // 30 秒 (毫秒)
    },
    
    // 地理圍欄顯示設定
    geofences: {
        enabled: true,
        showLabels: true,
        fillOpacity: 0.1,
        strokeWidth: 2
    },
    
    // 時區設定
    timezone: 'Asia/Taipei',  // 設定為台北時區
    
    // 除錯模式
    debug: false
};