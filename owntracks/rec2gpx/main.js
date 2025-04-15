function main() {
  console.log("Hello, World!");
  document.addEventListener('DOMContentLoaded', function() {
    // Date Range Picker
    const startDateInput = document.getElementById('startTime');
    const endDateInput = document.getElementById('endTime');
    const todayBtn = document.getElementById('todayBtn');
    const sevenDaysBtn = document.getElementById('sevenDaysBtn');
    const thirtyDaysBtn = document.getElementById('thirtyDaysBtn');
    
    // 日曆相關
    let selectedStartDate = null;
    let selectedEndDate = null;
    let currentDate = new Date();
    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];

    function updateDateRangeDisplay() {
        if (selectedStartDate && selectedEndDate) {
            const formattedStartDate = formatDate(selectedStartDate);
            const formattedEndDate = formatDate(selectedEndDate, true);
            if(startDateInput) startDateInput.value = formattedStartDate;
            if(endDateInput) endDateInput.value = formattedEndDate;
        }
    }


    function formatDate(date, isEndTime = false) {
        if (!date) return "";
        const year = date.getFullYear();
        const month = (date.getMonth() + 1).toString().padStart(2, '0');
        const day = date.getDate().toString().padStart(2, '0');
        const hour = isEndTime ? '23' : '00';
        const minute = isEndTime ? '59' : '00';
        return `${year}-${month}-${day} ${hour}:${minute}`;
    }
    
    function setDateRange(days) {
        const today = new Date();
        selectedEndDate = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 23, 59, 59);
        selectedStartDate = new Date(today.getFullYear(), today.getMonth(), today.getDate() - days, 0, 0, 0);
        updateDateRangeDisplay();
    }

    // Event Listeners



    if(todayBtn){
        todayBtn.addEventListener('click', () => {
            setDateRange(0);
        });
    }
    if(sevenDaysBtn){
        sevenDaysBtn.addEventListener('click', () => {
            setDateRange(6);
        });
    }

    if(thirtyDaysBtn){
        thirtyDaysBtn.addEventListener('click', () => {
            setDateRange(29);
        });
    }

    // 初始化日期
    const today = new Date();
    const year = today.getFullYear();
    const month = (today.getMonth() + 1).toString().padStart(2, '0');
    const day = today.getDate().toString().padStart(2, '0');
    selectedStartDate = new Date(`${year}-${month}-${day} 00:00:00`);    
    selectedEndDate = new Date(`${year}-${month}-${day} 23:59:59`);    
    if(startDateInput && endDateInput){
    updateDateRangeDisplay();
    }



    // Other Elements
    const fileInput = document.getElementById('recFile');
    const convertBtn = document.getElementById('convertBtn');
    const resultDiv = document.getElementById('result');
    const downloadBtn = document.getElementById('downloadBtn');
    const statsDiv = document.getElementById('stats');
    const errorDiv = document.getElementById('error');
    const outputDiv = document.getElementById('output');
    
    
    // 過濾選項元素
    const filterAccuracy = document.getElementById('filterAccuracy');
    const maxAccuracy = document.getElementById('maxAccuracy');
    const filterSpeed = document.getElementById('filterSpeed');
    const maxSpeed = document.getElementById('maxSpeed');
    const filterJumps = document.getElementById('filterJumps');
    const maxJump = document.getElementById('maxJump');
    
    let gpxContent = '';
    let fileName = '';
    let fileStartTime = null;
    let fileEndTime = null;
    
    // 計算兩點間距離 (使用 Haversine 公式)
    function calculateDistance(lat1, lon1, lat2, lon2) {
        const R = 6371e3; // 地球半徑，單位：公尺
        const φ1 = lat1 * Math.PI / 180; // 轉換為弧度
        const φ2 = lat2 * Math.PI / 180;
        const Δφ = (lat2 - lat1) * Math.PI / 180;
        const Δλ = (lon2 - lon1) * Math.PI / 180;

        const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
                  Math.cos(φ1) * Math.cos(φ2) *
                  Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return R * c; // 距離，單位：公尺
    }
    
    // 計算速度 (公尺/秒)
    function calculateSpeed(dist, time1, time2) {
        // 時間差，單位：秒
        const timeDiff = (time2 - time1) / 1000;
        if (timeDiff <= 0) return 0;
        return dist / timeDiff; // 公尺/秒
    }
    
    // 過濾點
    function filterPoints(points) {
        const filteredPoints = [];
        let removedAccuracy = 0;
        let removedSpeed = 0;
        let removedJumps = 0;
        let removedTime = 0;
        
        // 配置選項
        const useAccuracyFilter = filterAccuracy.checked;
        const maxAccuracyValue = parseFloat(maxAccuracy.value);
        const useSpeedFilter = filterSpeed.checked;
        const maxSpeedValue = parseFloat(maxSpeed.value) / 3.6; // 轉換為 m/s
        const useJumpFilter = filterJumps.checked;
        const maxJumpValue = parseFloat(maxJump.value);
        const startTimeFilter = startDateInput.value ? new Date(startDateInput.value).getTime() : null;
        const endTimeFilter = endDateInput.value ? new Date(endDateInput.value).getTime() : null;
        
        for (let i = 0; i < points.length; i++) {
            const point = points[i];
            let shouldKeep = true;;
            
            // 檢查時間範圍
            if (
                (startTimeFilter && point.timestamp < startTimeFilter) ||
                (endTimeFilter && point.timestamp > endTimeFilter)
            ) {
                removedTime++;
                shouldKeep = false;
            }
            
            // 檢查精確度
            if (useAccuracyFilter && shouldKeep && point.accuracy && point.accuracy > maxAccuracyValue) {
                removedAccuracy++;
                shouldKeep = false;
            }
            
            // 檢查與前一點的距離和速度
            if (shouldKeep && i > 0) {
                const prevPoint = points[i-1];
                const dist = calculateDistance(
                    point.lat, point.lon,
                    prevPoint.lat, prevPoint.lon
                );
                
                // 檢查跳躍
                if (useJumpFilter && dist > maxJumpValue) {
                    removedJumps++;
                    shouldKeep = false;
                }
                
                // 檢查速度
                if (useSpeedFilter && shouldKeep) {
                    const speed = calculateSpeed(
                        dist,
                        prevPoint.timestamp,
                        point.timestamp
                    );
                    if (speed > maxSpeedValue) {
                        removedSpeed++;
                        shouldKeep = false;
                    }
                }
            }
            
            if (shouldKeep) {
                filteredPoints.push(point);
            }
        }
        return {
            filteredPoints: filteredPoints,
            stats: {
                total: points.length,
                keptCount: filteredPoints.length,
                removedAccuracy,
                removedSpeed,
                removedJumps,
                removedTime,
                totalRemoved: removedAccuracy + removedSpeed + removedJumps + removedTime
            },
            startTime: points.length > 0 ? new Date(points[0].timestamp).toISOString().slice(0, 16) : null,
            endTime: points.length > 0 ? new Date(points[points.length - 1].timestamp).toISOString().slice(0, 16) : null
        };
    }

    // 新增的函數：處理檔案選擇事件
    fileInput.addEventListener('change', function() {
        if (!fileInput.files || fileInput.files.length === 0) {
            showError('請選擇一個檔案');
            return;
        }
        
        const file = fileInput.files[0];
        fileName = file.name.replace(/\.[^/.]+$/, '');
        const reader = new FileReader();
        
        // 清空之前的輸出
        outputDiv.innerHTML = '正在處理檔案...';
        errorDiv.textContent = '';
        resultDiv.style.display = 'none';
        
        reader.onload = function(e) {
            try {
                const recData = e.target.result;
                
                
                const result = convertRecToGpx(recData);


                // 設定預設的起訖時間
                if (result.startTime) {
                    startDateInput.value = result.startTime;
                } else {
                    startDateInput.value = "";
                }
                if (result.endTime) {
                    endDateInput.value = result.endTime;
                }

                outputDiv.innerHTML = '檔案已讀取, 請點擊轉換按鈕';
                
            } catch (err) {
                showError('檔案處理過程中發生錯誤: ' + err.message);
                outputDiv.innerHTML = '處理失敗，請檢查檔案格式是否正確';
            }
        };
        
        reader.onerror = function() {
            showError('無法讀取檔案');
            outputDiv.innerHTML = '檔案讀取失敗';
        };
        
        reader.readAsText(file);
    });

    
    convertBtn.addEventListener('click', function() {
        if (!fileInput.files || fileInput.files.length === 0) {
            showError('請選擇一個檔案');
            return;
        }
        
        const file = fileInput.files[0];
        fileName = file.name.replace(/\.[^/.]+$/, '');
        const reader = new FileReader();
        
        // 清空之前的輸出
        outputDiv.innerHTML = '正在處理檔案...';
        errorDiv.textContent = '';
        resultDiv.style.display = 'none';
        
        reader.onload = function(e) {
            try {
                const recData = e.target.result;
                const result = convertRecToGpx(recData);
                gpxContent = result.gpxContent;
                
                resultDiv.style.display = 'block';
                outputDiv.innerHTML = `
                    檔案已成功解析：
                    <br>- 原始軌跡點數：${result.originalCount}
                    <br>- 過濾後點數：${result.filteredCount}
                    <br>- 被移除點數：${result.removedCount}
                    <br>- 移除原因：
                    <br>&nbsp;&nbsp;- 精確度不佳：${result.stats.removedAccuracy}
                    <br>&nbsp;&nbsp;- 速度異常：${result.stats.removedSpeed}
                    <br>&nbsp;&nbsp;- 位置跳躍：${result.stats.removedJumps}
                    <br>&nbsp;&nbsp;- 時間範圍：${result.stats.removedTime}
                `;
                
                statsDiv.textContent = `成功轉換 ${result.filteredCount} 個有效地點 (過濾掉 ${result.removedCount} 個異常點)`;
                errorDiv.textContent = '';
                
            } catch (err) {
                showError('轉換過程中發生錯誤: ' + err.message);
                outputDiv.innerHTML = '處理失敗，請檢查檔案格式是否正確';
            }
        };
        
        reader.onerror = function() {
            showError('無法讀取檔案');
            outputDiv.innerHTML = '檔案讀取失敗';
        };
        
        reader.readAsText(file);
    });
    
    downloadBtn.addEventListener('click', function() {
        if (!gpxContent) {
            showError('沒有可下載的 GPX 內容，請先轉換檔案');
            return;
        }
        
        try {
            // 使用 Blob 和 URL.createObjectURL
            const blob = new Blob([gpxContent], { type: 'application/gpx+xml' });
            const url = URL.createObjectURL(blob);
            
            const tempLink = document.createElement('a');
            tempLink.href = url;
            tempLink.download = fileName + '.gpx';
            tempLink.style.display = 'none';
            document.body.appendChild(tempLink);
            
            // 觸發點擊事件以下載
            tempLink.click();
            
            // 清理
            setTimeout(() => {
                document.body.removeChild(tempLink);
                URL.revokeObjectURL(url);
            }, 100);
            
            outputDiv.innerHTML += '<br>檔案下載已開始';
        } catch (err) {
            showError('下載過程中發生錯誤: ' + err.message);
        }
    });
    
    function showError(message) {
        errorDiv.textContent = message;
    }
    
    function convertRecToGpx(recData) {
        // 解析每一行
        const lines = recData.split('\n').filter(line => line.trim());
        const points = [];
        let parseErrors = 0;
        
        lines.forEach((line, index) => {
            // 尋找 JSON 部分 (在第一個 { 開始)
            const jsonStart = line.indexOf('{');
            if (jsonStart === -1) return;
            
            const jsonStr = line.substring(jsonStart);
            try {
                const data = JSON.parse(jsonStr);
                
                // 只處理位置資料
                if (data._type === 'location' && data.lat && data.lon) {
                    points.push({
                        lat: data.lat,
                        lon: data.lon,
                        ele: data.alt || 0,
                        timestamp: data.tst * 1000, // 轉換為毫秒
                        time: new Date(data.tst * 1000).toISOString(),
                        accuracy: data.acc,
                        extras:{
                            accuracy: data.acc,
                            battery: data.batt,
                            velocity: data.vel,
                            connection: data.conn
                        }
                    });
                }
            } catch (error) {
                parseErrors++;
                console.error('解析 JSON 失敗:', error);
                console.error('問題行 #' + (index + 1) + ':', line);
            }
        });
        
        if (parseErrors > 0) {
            outputDiv.innerHTML += `<br>警告：解析過程中有 ${parseErrors} 行資料無法處理`;
        }
        
        // 排序點（依時間）
        points.sort((a, b) => a.timestamp - b.timestamp);
        
        // 過濾點
        const filteredResult = filterPoints(points);
        const gpxContent = generateGpx(filteredResult.filteredPoints)
        const filteredPoints = filteredResult.filteredPoints;
        
        // 生成 GPX 文件
        return {
            
            
            originalCount: points.length,
            filteredCount: filteredPoints.length,
            removedCount: points.length - filteredPoints.length,
            stats: filteredResult.stats,
            gpxContent:gpxContent,
            startTime: filteredResult.startTime,            
            endTime: filteredResult.endTime
        };
    }
    
    function generateGpx(points) {
        const header = '<?xml version="1.0" encoding="UTF-8" standalone="no" ?>\n' +
            '<gpx version="1.1" creator="OwnTracks-Rec-to-GPX-Converter" xmlns="http://www.topografix.com/GPX/1/1" ' +
            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' +
            'xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd" ' +
            'xmlns:owntracks="http://owntracks.org/gpx/1/0">\n';
        
        // 添加軌跡
        let trackContent = '  <trk>\n    <name>OwnTracks Recorder Track</name>\n    <trkseg>\n';
        
        // 添加每個軌跡點
        points.forEach(point => {
            trackContent += `      <trkpt lat="${point.lat}" lon="${point.lon}">\n`;
            trackContent += `        <ele>${point.ele}</ele>\n`;
            trackContent += `        <time>${point.time}</time>\n`;
            
            // 可選: 添加額外資訊為擴展數據
            if (point.extras) {
                trackContent += '        <extensions>\n';
                Object.keys(point.extras).forEach(key => {
                    if (point.extras[key] !== undefined) {
                        trackContent += `          <owntracks:${key}>${point.extras[key]}</owntracks:${key}>\n`;
                    }
                });
                trackContent += '        </extensions>\n';
            }
            
            trackContent += '      </trkpt>\n';
        });
        
        trackContent += '    </trkseg>\n  </trk>\n';
        const footer = '</gpx>';
        
        return header + trackContent + footer;
    }
});
}
    
main();
