shader_type canvas_item;

uniform float amplitude = 10.0; // ความสูงของคลื่น
uniform float frequency = 5.0;  // ความถี่คลื่น

void vertex() {
	// คำนวณการเลื่อนของแกน Y โดยใช้ฟังก์ชัน sine
	// ขึ้นอยู่กับตำแหน่ง X และเวลา
	float wave_offset = sin(VERTEX.x / 100.0 * frequency + TIME * 3.0) * amplitude;

	// เลื่อนตำแหน่ง VERTEX (จุด) ในแกน Y
	VERTEX.y += wave_offset;
}