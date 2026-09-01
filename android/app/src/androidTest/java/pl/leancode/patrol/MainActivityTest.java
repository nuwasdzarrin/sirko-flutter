package pl.leancode.patrol;

import androidx.test.platform.app.InstrumentationRegistry;

import com.sirko.sirko.MainActivity;

import org.junit.runner.RunWith;

import pl.leancode.patrol.PatrolJUnitRunner;

// Jembatan JUnit → Patrol. Runner ini menemukan seluruh test dart di
// integration_test/ dan menjalankannya di atas MainActivity aplikasi.
// Jangan tambahkan @Test manual di sini; Patrol meng-generate-nya saat runtime.
@RunWith(PatrolJUnitRunner.class)
public class MainActivityTest {
    @org.junit.BeforeClass
    public static void setUp() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
    }
}
