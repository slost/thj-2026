shader_type canvas_item;

uniform float speed = 0.5; // ความเร็วในการหมุน
uniform float spiral_tightness = 1.0; // ค่านี้กำหนดความแน่นของก้นหอย

void vertex() {
	// 1. ทำให้พิกัด UV อยู่ตรงกลาง (จาก 0-1 เป็น -0.5 ถึง 0.5)
	vec2 center_uv = UV - 0.5;

	// 2. คำนวณมุมและรัศมีของพิกัดปัจจุบัน
	float angle = atan(center_uv.y, center_uv.x);
	float radius = length(center_uv);

	// 3. คำนวณการเปลี่ยนแปลงของมุมตามเวลา
	float time_angle = TIME * speed;
    
    // 4. คำนวณการเปลี่ยนแปลงรัศมีตามเวลา (เพื่อทำให้เป็นก้นหอย)
    // การเพิ่มค่า TIME เข้าไปในรัศมีจะทำให้ texture ดูเหมือน "พุ่ง" ออกมา
    float new_radius = radius + TIME * 0.1 * spiral_tightness; // 0.1 เป็นอัตราการขยาย

	// 5. คำนวณตำแหน่งใหม่ (Offset) ด้วยสูตรการเคลื่อนที่แบบวงกลม
    // โดยใช้มุมที่เปลี่ยนแปลงและรัศมีใหม่
	float offset_x = new_radius * cos(angle + time_angle);
	float offset_y = new_radius * sin(angle + time_angle);
    
    // 6. ใช้ตำแหน่งที่คำนวณได้เป็น UV ใหม่ (วนกลับไปเป็น 0-1)
    // การใช้ offset โดยตรงอาจทำให้เกิดผลลัพธ์ที่แปลกประหลาด
    // เราจะใช้ offset เพื่อ *เลื่อน* texture แทน
	UV.x += offset_x * 0.1; // 0.1 เป็นค่าปรับขนาดการเลื่อน
	UV.y += offset_y * 0.1; // ปรับค่านี้เพื่อควบคุมการเลื่อน

}