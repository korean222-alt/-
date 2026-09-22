// 작은 CFrame 계산기. rbx_types 의 CFrame 은 회전 행렬을 "행" 단위로 담기 때문에
// 여기서도 행 우선(row-major) 3x3 으로 다룬다.
use rbx_types::{CFrame, Matrix3, Vector3};

#[derive(Clone, Copy, Debug)]
pub struct Frame {
    pub pos: [f32; 3],
    pub rot: [[f32; 3]; 3], // rot[row][col]
}

pub const IDENTITY: [[f32; 3]; 3] = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]];

impl Frame {
    pub fn new(pos: [f32; 3]) -> Self {
        Frame { pos, rot: IDENTITY }
    }

    pub fn with_rot(pos: [f32; 3], rot: [[f32; 3]; 3]) -> Self {
        Frame { pos, rot }
    }

    /// Y축 회전(요) 행렬. LookVector = -(sin a, 0, cos a) 가 된다.
    pub fn yaw(pos: [f32; 3], angle: f32) -> Self {
        let (s, c) = (angle.sin(), angle.cos());
        Frame {
            pos,
            rot: [[c, 0.0, s], [0.0, 1.0, 0.0], [-s, 0.0, c]],
        }
    }

    /// 주어진 방향을 바라보는 프레임. (수평 방향만 다룬다)
    pub fn look_at(pos: [f32; 3], look: [f32; 3]) -> Self {
        let len = (look[0] * look[0] + look[1] * look[1] + look[2] * look[2]).sqrt();
        let l = [look[0] / len, look[1] / len, look[2] / len];
        let z = [-l[0], -l[1], -l[2]]; // Z 열 = -LookVector
        let y = [0.0f32, 1.0, 0.0];
        // X = Y × Z
        let x = [
            y[1] * z[2] - y[2] * z[1],
            y[2] * z[0] - y[0] * z[2],
            y[0] * z[1] - y[1] * z[0],
        ];
        let xl = (x[0] * x[0] + x[1] * x[1] + x[2] * x[2]).sqrt();
        let x = [x[0] / xl, x[1] / xl, x[2] / xl];
        Frame {
            pos,
            // 열이 X, Y, Z 이므로 행은 각 축의 같은 성분을 모은다.
            rot: [[x[0], y[0], z[0]], [x[1], y[1], z[1]], [x[2], y[2], z[2]]],
        }
    }

    pub fn rot_x(angle: f32) -> [[f32; 3]; 3] {
        let (s, c) = (angle.sin(), angle.cos());
        [[1.0, 0.0, 0.0], [0.0, c, -s], [0.0, s, c]]
    }

    /// self * other (행렬 곱 + 위치 변환)
    pub fn mul(&self, other: &Frame) -> Frame {
        let mut rot = [[0.0f32; 3]; 3];
        for i in 0..3 {
            for j in 0..3 {
                rot[i][j] = self.rot[i][0] * other.rot[0][j]
                    + self.rot[i][1] * other.rot[1][j]
                    + self.rot[i][2] * other.rot[2][j];
            }
        }
        let mut pos = [0.0f32; 3];
        for i in 0..3 {
            pos[i] = self.pos[i]
                + self.rot[i][0] * other.pos[0]
                + self.rot[i][1] * other.pos[1]
                + self.rot[i][2] * other.pos[2];
        }
        Frame { pos, rot }
    }

    pub fn rotated(&self, rot: [[f32; 3]; 3]) -> Frame {
        self.mul(&Frame::with_rot([0.0, 0.0, 0.0], rot))
    }

    pub fn translated(&self, offset: [f32; 3]) -> Frame {
        self.mul(&Frame::new(offset))
    }

    /// LookVector = -(3열)
    pub fn look_vector(&self) -> [f32; 3] {
        [-self.rot[0][2], -self.rot[1][2], -self.rot[2][2]]
    }

    pub fn to_cframe(&self) -> CFrame {
        CFrame::new(
            Vector3::new(self.pos[0], self.pos[1], self.pos[2]),
            Matrix3::new(
                Vector3::new(self.rot[0][0], self.rot[0][1], self.rot[0][2]),
                Vector3::new(self.rot[1][0], self.rot[1][1], self.rot[1][2]),
                Vector3::new(self.rot[2][0], self.rot[2][1], self.rot[2][2]),
            ),
        )
    }

    pub fn from_cframe(cf: &CFrame) -> Frame {
        Frame {
            pos: [cf.position.x, cf.position.y, cf.position.z],
            rot: [
                [cf.orientation.x.x, cf.orientation.x.y, cf.orientation.x.z],
                [cf.orientation.y.x, cf.orientation.y.y, cf.orientation.y.z],
                [cf.orientation.z.x, cf.orientation.z.y, cf.orientation.z.z],
            ],
        }
    }

    /// (pivotX, pivotZ) 를 지나는 수직축 기준으로 180도 돌린다.
    pub fn spin_180_about(&self, pivot_x: f32, pivot_z: f32) -> Frame {
        let ry180 = [[-1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, -1.0]];
        let pivot = Frame::new([pivot_x, 0.0, pivot_z]);
        let inv_pivot = Frame::new([-pivot_x, 0.0, -pivot_z]);
        pivot
            .mul(&Frame::with_rot([0.0, 0.0, 0.0], ry180))
            .mul(&inv_pivot)
            .mul(self)
    }
}
