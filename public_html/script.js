var updateInterval = 5; // Интервал обновления данных в секундах

let dataSize = (60 / updateInterval) * 60 * 24; // Размер данных по умолчанию (1 день)
let currentDays = 1; // Текущий интервал в днях
var maxDays = 1;

var ctx = document.getElementById('loadavg');
var ds1 = [];
var ds5 = [];
var ds15 = [];
var labels = [];

var chart = new Chart(ctx, {
    type: 'line',
    data: {
	labels: labels,
	datasets: [{
	    label: '1m',
	    data: ds1,
	    borderColor: 'rgba(255, 0, 0, 1)',
	    borderWidth: 2,
	    fill: false // Установите fill в false
	}, {
	    label: '5m',
	    data: ds5,
	    borderColor: 'rgba(255, 184, 28, 1)',
	    borderWidth: 2,
	    fill: false // Установите fill в false
	}, {
	    label: '15m',
	    data: ds15,
	    borderColor: 'rgba(0, 255, 0, 1)',
	    borderWidth: 2,
	    fill: false // Установите fill в false
	}]
    },
    options: {
	animation: false,
	elements: {
	    point: {
		radius: 0
	    }
	},
	maintainAspectRatio: false,
	responsive: true,
	scales: {
	    x: {
		title: {
		    display: false,
		    text: 'Время',
		    font: {
			size: 16 // Увеличьте размер шрифта для оси X
		    }
		},
		grid: {
		    display: true // Отображение сетки на оси X
		}
	    },
	    y: {
		title: {
		    display: false,
		    text: 'Загрузка',
		    font: {
			size: 16 // Увеличьте размер шрифта для оси Y
		    }
		},
		grid: {
		    display: true // Отображение сетки на оси Y
		}
	    }
	},
	plugins: {
	    legend: {
		display: true // Отображение легенды
	    },
	    tooltip: {
		enabled: true // Включить подсказки
	    }
	}
    }
});

function addData(chart, label, newData) {
    chart.data.labels.push(label);
    chart.data.datasets.forEach((dataset, i) => {
	dataset.data.push(newData[i]);
    });
    chart.update();
}

function removeData(chart) {
    chart.data.labels.shift();
    chart.data.datasets.forEach((dataset) => {
	dataset.data.shift();
    });
    chart.update();
}

function getDays() {
    fetch("/days")
	.then((r) => { return r.json(); })
	.then((days) => {
	    maxDays = days;
	    populateDaysSelect(maxDays);
	    dataSize = (60 / updateInterval) *60 * 24 * days;
	    loadDays(currentDays);
	})
	.catch(e => console.log(e));
}

function getUpdateInterval() {
    fetch("/update")
	.then((r) => {return r.json();})
	.then((newUpdateInterval) => {
	    updateInterval = newUpdateInterval;
	    getDays();
	})
	.catch(e => console.log(e));
}

function populateDaysSelect(maxDays) {
    const select = document.getElementById('days');
    for (let i = 1; i <= maxDays; i++) {
	const option = document.createElement('option');
	option.value = i;
	option.textContent = `${i}`;
	select.appendChild(option);
    }
    select.value = currentDays;
    select.addEventListener('change', updateChart); // Обновляем график при изменении выбора
}

function updateChart() {
    const select = document.getElementById('days');
    currentDays = select.value;
    loadDays(currentDays);
}

function reloadAvg() {
    fetch("/last")
	.then((response) => { return response.json(); })
	.then((json) => {
	    addData(chart, json.date, json.avg);
	    if (chart.data.labels.length > dataSize) {
		removeData(chart);
	    }
	    setTimeout(reloadAvg, updateInterval * 1000);
	});
}

function loadDays(days) {
    fetch(`/dump?days=${days}`)
	.then((response) => { return response.json(); })
	.then((dataSet) => {
	    chart.data.datasets[0].data.length = 0;
	    chart.data.datasets[1].data.length = 0;
	    chart.data.datasets[2].data.length = 0;
	    chart.data.labels.length = 0;
	    dataSet.forEach(entry => {
		if (Object.keys(entry).length > 0) {
		    chart.data.labels.push(entry.date);
		    chart.data.datasets.forEach((dataset, i) => {
			dataset.data.push(entry.avg[i]);
		    });
		}
	    });
	    chart.update();
	    setTimeout(reloadAvg, updateInterval * 1000);
	})
	.catch(e => console.log(e));
}


getUpdateInterval();
